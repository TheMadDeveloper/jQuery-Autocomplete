#= require views/application/popovers/FilterResultInfoPopover

window.FilterListView = class FilterListView extends Support.CompositeView
  _.attrAccessor(@, "results")

  events:
    "keydown": (e) -> e.preventDefault() if e.keyCode == 13 # Prevent 'enter' from submitting the form
    "click .fl-close": "_hide"
    "click .next-page": "_pageResults"
    "click .previous-page": "_pageResults"
    "change .fl-tag": "_search"

  @CATEGORY_MAP:
    TYPE_TO_CAT:
      "lesson": "Lessons"
      "series": "Series"
    CAT_TO_TYPE:
      "Lessons": "lesson"
      "Series": "series"

  @resultTpls:
    default:
      _.template("""
        <div class="<%= searchResult.type() %> popover-trigger hover" data-result-cid="<%= searchResult.cid %>" data-popover="filterResultInfo">
          <span class="result-name"><%= searchResult.name() %></span>
          <a class="result-link" href="<%= searchResult.resultUrl() %>" target="_blank"><i class="fa fa-external-link"></i></a>
          <ul class="meta-data">
            <% if (searchResult.type() == 'series') { %><li class="lesson-count"><%= searchResult.lessonCount() %> Lessons</li><% } %>
            <li class="duration"><i class="fa fa-clock-o"></i> <%= searchResult.duration() %></li>
            <li><i class="fa fa-user"></i> <%= searchResult.presenterName() %></li>
          </ul>
        </div>
      """)

  @categoryHeadingTpl:
    _.template("""
      <div class="pull-right page-control">
        <a href="#" class="previous-page" data-page-type="<%= resultType %>"><i class="fa fa-caret-left"></i></a>
        <strong><%= range[0] %> &ndash; <%= range[1] %></strong> of <%= results.total({'for': resultType}) %>
        <a href="#" class="next-page" data-page-type="<%= resultType %>"><i class="fa fa-caret-right"></i></a>
      </div>
      <strong><%= name %></strong>
    """)

  _suggestions: []
  _searchRequest: null  # Stores the deferred xhr object when fetching results

  options:
    searchOptions: {}

  initialize: (options={}) =>
    @$input = @$("input.filter")

    isDocked = @$el.hasClass("fl-docked")

    options.$triggers.on("click", @_toggle)

    @$input.autocomplete(
      minChars: if @options.autoSuggest then 0 else 3
      lookup: @_findSuggestions
      formatResult: @_renderSuggestion
      groupBy: "category"
      maxHeight: null
      width: null if isDocked
      preserveInput: true
      appendTo: @$(".suggestion-container")
      preventBadQueries: false # If "calc" returns no results, don't abort searches for "calculus"
      showNoSuggestionNotice: true
    )

    @$suggestions = $(".autocomplete-suggestions")

    # If this list is docked (and we have a place for the suggestions) we don't want the suggestions to be absolute
    # or have a z-index.  The autocomplete plugin likes to pre-assign these in the style parameter, so nuke it.
    # We control the styles now!
    @$suggestions.attr("style",null) if isDocked

    # We want the suggestions to persist and not to perform any selection behavior.  Since the various autocomplete
    # events do not allow preventing default behavior, well have to overwrite certain class methods
    instance = @$input.data("autocomplete")
    instance.hide = => #NOOP
    instance.onSelect = => #NOOP

    searchOptions = @options.searchOptions
    searchOptions.perPage ||= 10

    # We'll reuse the same SearchResults object for every search
    @results(new SearchResults(searchOptions))

    PopoverManager.instance(
      popoverViews:
       filterResultInfo: new FilterResultInfoPopover(source: => @results())
    )

  leave: =>
    super
    @$input.autocomplete('dispose') # teardown the autocomplete plugin on uninitialization

  # Intended to be the autocomplete plugins "lookup" function -- arguments are non-negotiable
  _findSuggestions: (query, _lookupCallback) =>
    @_lookupCallback ?= _lookupCallback # We'll need a reference to this for paging results
    @results().setQueryOptions(
      _.merge(@options.searchOptions, query: query, page: 0, internalTags: @_internalTags())
    )
    @_fetch(=> @results().fetch(reset: true))

  # Fetches the next page of results, configured via triggering elements "class" and "data-page-type" attributes
  _pageResults: (evt) =>
    $trigger = $(evt.currentTarget)
    pageType = $trigger.data("page-type")

    # Figure out if we are using the fetchNext or fetchPrevious page function
    @_fetch(=> if $trigger.hasClass("previous-page") then @results().fetchPreviousPage(pageType) else @results().fetchNextPage(pageType))

  _fetch: (fnFetch) =>
    @_searchRequest?.abort()
    @_setLoading(true)
    @_searchRequest = fnFetch().done( =>
      @_suggest()
    ).always( =>
      @_setLoading(false)
    )

  # Make/render suggestions (based on the current @results object)
  _suggest: (suggestions=null) =>
    suggestions ||= @_buildSuggestData(@results())
    @_lookupCallback(suggestions: suggestions)

    @$suggestions
      .find("[data-result-cid]")
        .draggable(
          revert: "invalid",
          helper: "clone",
          connectToSortable: "#teachables",
          zIndex: 10000, # FIXME: the nuclear z-index option is overkill
          appendTo: document.body, # Only documented for sortable, but works for draggable
          forceHelperSize: true,
          start: (evt, ui) =>
            ui.helper
              .width($(evt.currentTarget).width())
              .removeClass("popover-trigger")
              .find("ul.meta-data").remove()
        )
        .end()
      .find(".autocomplete-group")
        .each( (i, el) =>
          # There is no way to custom format category headings in the autocomplete plugin, so we'll have to finagle it
          $catRow = $(el)
          category = $catRow.text() # ...yeah, that's right... whatcha gonna do about it?
          $catRow.html(@_renderCategoryHeading(category, @results()))
        )

  # autocomplete plugin likes its suggestions in this format
  _buildSuggestData: (results) =>
    results.map(
      (searchResult) =>
        value: searchResult.name(),
        data:
          result: searchResult
          category: @constructor.CATEGORY_MAP.TYPE_TO_CAT[searchResult.type()]  # For autocomplete to group, this needs
    )                                                                           # to be a siple data value, so take your
                                                                                # fancy classes and go back to college!

  _setLoading: (toggle) =>
    @$(".box-icon .fa")
      .toggleClass("fa-search", !toggle)
      .toggleClass("fa-refresh fa-spin", toggle)

    # Disable pagination buttons while search is running
    @$(".page-control a").prop("disabled", toggle)

  _renderSuggestion: (suggestion, search) =>
    internalRating = suggestion.data.result.internalRating()
    ratingHtml = ""
    searchResult = suggestion.data.result
    template = @constructor.resultTpls[searchResult.type()] || @constructor.resultTpls.default
    template(
      searchResult: searchResult
      search: search
      internalRating: ratingHtml
    )

  _renderCategoryHeading: (categoryName, results) =>
    resultType = @constructor.CATEGORY_MAP.CAT_TO_TYPE[categoryName]
    resultSet = results.getResultSet(resultType)

    @constructor.categoryHeadingTpl(
      name: categoryName
      resultType: resultType
      results: results
      range: results.resultRange(resultType)
    )

  _internalTags: =>
    tags = []
    @$(".fl-tag:checked").each ->
      tags = tags.concat($(@).attr("data-tag"))
    tags

  _toggle: =>
    if @$el.hasClass("fl-open")
      @_hide()
    else
      @_show()

  _search: =>
    # Trigger autocomplete to run a new search.
    # This isn't a documented method that you can call, but it does work
    # (basically we're calling the same method on the plugin that it calls on
    # itself after a keyup event).
    @$input.autocomplete("onValueChange")

  _hide: =>
    @$el.removeClass("fl-open")

  _show: =>
    @$el.addClass("fl-open")
    @$input.focus()
