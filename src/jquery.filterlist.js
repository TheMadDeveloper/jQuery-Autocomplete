/**
 * Created by kkerlan on 4/14/16.
 */
/**
 *  Ajax FilterList for jQuery, version %version%
 *  (c) 2016 Keith Kerlan
 *
 *  Ajax LiveSearch for jQuery is freely distributable under the terms of an MIT-style license.
 *  For details, see the web site:
 */

/*jslint  browser: true, white: true, plusplus: true, vars: true */
/*global define, window, document, jQuery, exports, require */

// Expose plugin as an AMD module if AMD loader is present:
(function (factory) {
    'use strict';
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof exports === 'object' && typeof require === 'function') {
        // Browserify
        factory(require('jquery'));
    } else {
        // Browser globals
        factory(jQuery);
    }
}(function ($) {
    'use strict'

    function LiveSearch(el, options) {

        var me = this;
        var isDocked = el.hasClass("ls-docked");

        me.element = el;
        me.options = options;
        if (options.$triggers) {
            options.$triggers.on("click", function(e) { me.toggle(e, me) });
        }

        el.autocomplete({
            minChars: options.autoSuggest ? 0 : 3,
            lookup: me._findSuggestions,
            formatResult: me._renderSuggestion,
            groupBy: "category",
            maxHeight: null,
            width: null,
            preserveInput: true,
            appendTo: $(".suggestion-container"),
            preventBadQueries: false, // If "calc" returns no results, don't abort searches for "calculus"
            showNoSuggestionNotice: true
        });

        me.$suggestions = $(".autocomplete-suggestions");

        // If this list is docked (and we have a place for the suggestions) we don't want the suggestions to be absolute
        // or have a z-index.  The autocomplete plugin likes to pre-assign these in the style parameter, so nuke it.
        // We control the styles now!
        if (isDocked) {
            me.$suggestions.attr("style",null);
        }

        // We want the suggestions to persist and not to perform any selection behavior.  Since the various autocomplete
        // events do not allow preventing default behavior, well have to overwrite certain class methods
        var instance = el.data("autocomplete");

        instance.hide = function() { };     // NOOP
        instance.onSelect = function() {};  // NOOP

        var searchOptions = options.searchOptions || 10;

        // We'll reuse the same SearchResults object for every search
        //@results(new SearchResults(searchOptions))
        //
        //PopoverManager.instance(
        //    popoverViews:
        //filterResultInfo: new FilterResultInfoPopover(source: => @results())
        //}
    }

    $.FilterList = FilterList;

    $.extend(LiveSearch.prototype, {
        // Intended to be the autocomplete plugins "lookup" function -- arguments are non-negotiable
        _findSuggestions: function(query, _lookupCallback) {
            if (!this._lookupCallback) {
                this._lookupCallback = _lookupCallback; // We'll need a reference to this for paging results
            }

            if (this.options.lookup) {
                var lookupUrl = this.options.lookup(query);
            }
            results().setQueryOptions(
                _.merge(@options.searchOptions, query
            :
            query, page
            :
            0, internalTags
            : @_internalTags()
            )
            )
            @_fetch(= > @results().fetch(reset
            :
            true
            ))
        },

        dispose: function () {
            this.element.autocomplete('dispose');
        }
    });

    // Create chainable jQuery plugin:
    $.fn.autocomplete = $.fn.devbridgeAutocomplete = function (options, args) {
        var dataKey = 'autocomplete';
        // If function invoked without argument return
        // instance of the first matched element:
        if (arguments.length === 0) {
            return this.first().data(dataKey);
        }

        return this.each(function () {
            var inputElement = $(this),
                instance = inputElement.data(dataKey);

            if (typeof options === 'string') {
                if (instance && typeof instance[options] === 'function') {
                    instance[options](args);
                }
            } else {
                // If instance already exists, destroy it:
                if (instance && instance.dispose) {
                    instance.dispose();
                }
                instance = new Autocomplete(this, options);
                inputElement.data(dataKey, instance);
            }
        });
    };
}));

