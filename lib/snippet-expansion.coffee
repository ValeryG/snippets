{CompositeDisposable} = require 'atom'
{memoize} = require 'memoizee'

module.exports =
class SnippetExpansion
  settingTabStop: false

  constructor: (@snippet, @editor, @cursor, @snippets) ->
    @subscriptions = new CompositeDisposable
    @tabStopMarkers = []
    @selections = [@cursor.selection]

    startPosition = @cursor.selection.getBufferRange().start

    @editor.transact =>
      newRange = @editor.transact =>
          @setChar = (i) =>
             if  i < @snippet.body.length
                if  @snippet.body[i] != ' '
                    audio = new Audio(__dirname+'/../audio/key_press.mp3')
                    #audio.volume = 0.5;
                    #audio.play();
                @cursor.selection.insertText(@snippet.body[i], autoIndent: false)
                tmO = 100
                if i < @snippet.body.length-2 && @snippet.body[i+1] == ' '
                    tmO = 0
                setTimeout () =>
                    @setChar(i+1)
                ,tmO
             else
              if @snippet.tabStops.length > 0
                  @subscriptions.add @cursor.onDidChangePosition (event) => @cursorMoved(event)
                  @subscriptions.add @cursor.onDidDestroy => @cursorDestroyed()
                  @placeTabStopMarkers(startPosition, @snippet.tabStops)
                  @snippets.addExpansion(@editor, this)
              @indentSubsequentLines(startPosition.row, @snippet) if @snippet.lineCount > 1
          @setChar(0)

  cursorMoved: ({oldBufferPosition, newBufferPosition, textChanged}) ->
    return if @settingTabStop or textChanged
    @destroy() unless @tabStopMarkers[@tabStopIndex].some (marker) ->
      marker.getBufferRange().containsPoint(newBufferPosition)

  cursorDestroyed: -> @destroy() unless @settingTabStop

  placeTabStopMarkers: (startPosition, tabStopRanges) ->
    for ranges in tabStopRanges
      @tabStopMarkers.push ranges.map ({start, end}) =>
        @editor.markBufferRange([startPosition.traverse(start), startPosition.traverse(end)])
    @setTabStopIndex(0)

  indentSubsequentLines: (startRow, snippet) ->
    initialIndent = @editor.lineTextForBufferRow(startRow).match(/^\s*/)[0]
    for row in [startRow + 1...startRow + snippet.lineCount]
      @editor.buffer.insert([row, 0], initialIndent)

  goToNextTabStop: ->
    nextIndex = @tabStopIndex + 1
    if nextIndex < @tabStopMarkers.length
      if @setTabStopIndex(nextIndex)
        true
      else
        @goToNextTabStop()
    else
      @destroy()
      false

  goToPreviousTabStop: ->
    @setTabStopIndex(@tabStopIndex - 1) if @tabStopIndex > 0

  setTabStopIndex: (@tabStopIndex) ->
    @settingTabStop = true
    markerSelected = false

    ranges = []
    for marker in @tabStopMarkers[@tabStopIndex] when marker.isValid()
      ranges.push(marker.getBufferRange())

    if ranges.length > 0
      selection.destroy() for selection in @selections[ranges.length...]
      @selections = @selections[...ranges.length]
      for range, i in ranges
        if @selections[i]
          @selections[i].setBufferRange(range)
        else
          newSelection = @editor.addSelectionForBufferRange(range)
          @subscriptions.add newSelection.cursor.onDidChangePosition (event) => @cursorMoved(event)
          @subscriptions.add newSelection.cursor.onDidDestroy => @cursorDestroyed()
          @selections.push newSelection
      markerSelected = true

    @settingTabStop = false
    markerSelected

  destroy: ->
    @subscriptions.dispose()
    for markers in @tabStopMarkers
      marker.destroy() for marker in markers
    @tabStopMarkers = []
    @snippets.clearExpansions(@editor)

  restore: (@editor) ->
    @snippets.addExpansion(@editor, this)
