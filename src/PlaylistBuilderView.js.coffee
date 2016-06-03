window.PlaylistBuilderView = class PlaylistBuilderView extends Support.CompositeView

  @rowTemplate: _.template("""
    <tr class="item-row modified">
      <td class="col-position">
        <input id="playlist_teachable_in_playlists_attributes_<%= index %>_position" name="<%= inputPrefix %>[teachable_in_playlists_attributes][<%= index %>][position]" size="30" type="text">
        <input id="playlist_teachable_in_playlists_attributes_<%= index %>_id" name="<%= inputPrefix %>[teachable_in_playlists_attributes][<%= index %>][id]" type="hidden" value="">
        <input id="playlist_teachable_in_playlists_attributes_<%= index %>_teachable_type" name="<%= inputPrefix %>[teachable_in_playlists_attributes][<%= index %>][teachable_type]" type="hidden" value="<%= _.classify(itemType) %>" class="teachable-type">
        <input id="playlist_teachable_in_playlists_attributes_<%= index %>_teachable_id" name="<%= inputPrefix %>[teachable_in_playlists_attributes][<%= index %>][teachable_id]" type="hidden" value="<%= itemId %>" class="teachable-id">
        <input id="playlist_teachable_in_playlists_attributes_<%= index %>__destroy" name="<%= inputPrefix %>[teachable_in_playlists_attributes][<%= index %>][_destroy]" type="hidden" value="false">
      </td>
      <% if(showRating) { %>
        <td class="col-rating"><%= _.isNumber(item.internalRating()) ? item.internalRating() : 'NR' %></td>
      <% } %>
      <% if(showType) { %>
        <td class="col-type"><%= itemType %></td>
      <% } %>
      <td class="col-duration">
        <%= item.duration() %>
        <% if (itemType == "series") { %><div class="details"><%= item.lessonCount() %> Parts</div><% } %>
      </td>
      <% if(showAuthor) { %>
        <td class="col-author"><%= item.presenterName() %></td>
      <% } %>
      <td>
        <%= item.name() %>
        <div class="details">
          <%= item.description() %>
        </div>
      </td>
      <td class="col-utils">
        <div class="hover-utils pull-right">
          <i class="fa fa-info-circle util toggle-details"></i>
          <a href="<%= item.resultUrl() %>" target="_blank"><i class="fa fa-external-link-square util"></i></a>
          <i class="fa fa-times util remove"></i>
        </div>
      </td>
    </tr>
  """)

  @plhTemplate: _.template("""
    <tr class="placeholder"><td colspan="<%= columnCount %>"></td></tr>
  """)

  events: =>
    "click .util.remove": (evt) => @_removeItem($(evt.currentTarget))
    "click .util.undo-remove": (evt) => @_removeItem($(evt.currentTarget), false)
    "click .util.toggle-details": (evt) => @_toggleDetails($(evt.currentTarget), true)
    "mouseleave .util.toggle-details": (evt) => @_toggleDetails($(evt.currentTarget), false)
    "keydown": (e) -> e.preventDefault() if e.keyCode == 13 # Prevent 'enter' in position column from submitting the form

  numItems: 0
  columnCount: -1

  options:
    inputPrefix: "playlist"
    showRating: false
    showType: false
    showAuthor: false

  # inputPrefix should be the form.object_name from the rails form.
  initialize: (options={}) =>
    @columnCount = @$('th').length
    @_updateOrder()

    # Prerender placeholder element
    @plhElement = $(@constructor.plhTemplate(columnCount: @columnCount)).get(0)

    @filterListView = options.filterListView

    PopoverManager.instance(
      popoverViews:
        playlistItemInfo: new FilterResultInfoPopover(source: => @results())
    )

    @$el.sortable(
      revert: true,
      items: "tr.item-row",
      beforeStop: (evt, ui) =>
        if ui.item.hasClass("helper-wrap")
          @_wrapHelper(ui.item, false)
        else if ui.item[0].tagName != "TR"
          @_convertDroppedToRow(ui.item)

        @_updateOrder()

      # Hack to change the placeholder element--working as of jquery-ui 1.11.4...but may not work forever
      # See: http://stackoverflow.com/questions/2150002/jquery-ui-sortable-how-can-i-change-the-appearance-of-the-placeholder-object
      placeholder:
        element: (currentItem) =>
          @plhElement
        update: (container, p) =>
          return
      forceHelperSize: true

      helper: (evt, element) =>
        @_wrapHelper($(element),true).get(0)
    )

  leave: =>
    super
    @$el.sortable("destroy") # teardown the sortable plugin on uninitialization

  # Returns an ordered array of ids for all lessons in the playlist
  lessonIds: =>
    @_idsOfType("Lesson")

  # Returns an ordered array of ids for all series in the playlist
  seriesIds: =>
    @_idsOfType("Series")

  # Given a teachable type, returns an ordered array of ids for all teachables
  # of that type in the playlist.
  _idsOfType: (type) =>
    ids = []
    @$(".item-row").each ->
      ids = ids.concat($(@).find(".teachable-id").val()) if $(@).find(".teachable-type").val() == type
    ids

  # Wraps (or unwraps) the drag element (helper) so that the row maintains the same appearance as when it's not being
  # dragged (something that doesn't happen naturally since we tragging tr elements)
  _wrapHelper: ($helper, toggle) =>
    if toggle
      $helper.addClass("helper-wrap")
      $helper.wrapInner("<td colspan=\"#{@columnCount}\"><table><tr></tr></table></td>")
    else
      $cols = $helper.find("table td").detach()
      $helper.empty().append($cols)
      $helper.removeClass("helper-wrap")

    $helper

  _convertDroppedToRow: ($dropped) =>
    itemCid = $dropped.attr("data-result-cid")
    result = @filterListView.results().get(cid: itemCid)
    # NOTE: use the raw 'id' attribute, not the +.id+ accessor (which get
    #       overridden to "<type>-<id>". See +SearchResult+ for details.
    itemId = result.get("id")
    itemType = result.type()

    templateOptions =
      index: @numItems
      itemId: itemId
      itemType: itemType
      item: result
      inputPrefix: @inputPrefix
    _.extend(templateOptions, _.pick(@options, "inputPrefix", "showRating", "showType", "showAuthor"))
    $dropped.replaceWith(@constructor.rowTemplate(
      templateOptions
    ))

  _updateOrder: =>
    $rows = @$("tr.item-row")
    @numItems = $rows.length
    for i in [0..@numItems-1]
      $row = $rows.eq(i)
      pos = i + 1
      initPos = $row.data("initial-order")
      @_getItemField($row, "position").val(pos)
      $row.toggleClass("modified", pos != initPos)

    @$("tr.empty-row").remove() if @numItems > 0

  _removeItem: ($trigger, toggle=true) =>
    $trigger
      .toggleClass("remove fa-times", !toggle) # Classes for remove button
      .toggleClass("undo-remove fa-undo", toggle) # Classes for undo button

    $row = $trigger.closest("tr")
    $row.toggleClass("removed", toggle).toggleClass("item-row", !toggle)

    if toggle
      # Remove item
      @_getItemField($row, "_destroy").val(true)
      @_getItemField($row, "position").val("")
    else
      # Restore item
      @_getItemField($row, "_destroy").val(false)

    @_updateOrder()

  _toggleDetails: ($trigger, toggle) =>
    $trigger.closest("tr").toggleClass("show-details", toggle)

  _getItemField: ($row, field) =>
    # Find an input with an id that ends in _field. This is based on rails's default (and verbose) id format for nested models.
    $row.find("input[id$=_#{field}]")
