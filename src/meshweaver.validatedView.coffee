@Meshweaver ||= {}

defaultOptions =
  saveExistingOnChange: true

class @Meshweaver.ValidatedView
  constructor: (self, options) ->
    @self = self
    @options = _.extend({}, defaultOptions, options)
    @statusRowClass = '.row-status'

  bindUIElements: ->
    @_bindUIElements()
    @_bindUIErrorElements()
    _.invoke @_behaviors, @_bindUIElements
    _.invoke @_behaviors, @_bindUIErrorElements
    return

  _bindUIErrorElements: ->
    if !@uiError
      return
    # store the uiError hash in _uiErrorBindings so they can be reset later
    # and so re-rendering the view will be able to find the bindings
    if !@_uiErrorBindings
      @_uiErrorBindings = @uiError
    # get the bindings result, as a function or otherwise
    bindings = _.result(@, '_uiErrorBindings')
    # empty the uiError so we don't have anything to start with
    @uiError = {}
    # bind each of the selectors
    _.each bindings, ((selector, key) ->
      @uiError[key] = @$(selector)
      return
    ), @
    return

  unbindUIElements: ->
    @_unbindUIElements()
    @_unbindUIErrorElements()
    _.invoke @_behaviors, @_unbindUIElements
    _.invoke @_behaviors, @_unbindUIErrorElements
    return

  _unbindUIErrorElements: ->
    if !@uiError or !@_uiErrorBindings
      return
    # delete all of the existing uiError bindings
    _.each @uiError, (($el, name) ->
      delete @uiError[name]
      return
    ), @
    # reset the uiError element to the original bindings configuration
    @uiError = @_uiErrorBindings
    delete @_uiErrorBindings
    return

  configureValidation: =>
    Meshweaver.Validation.bind @self,
      valid: (view, attr) =>
        uiBind = view.uiError?[attr] || view.ui?[attr]
        return unless uiBind?
        uiBind.toggleClass('input-validation-error', false) if uiBind
        $item = @ensureValidationSummaryItem attr
        $item.toggleClass "hide", true
      invalid: (view, attr, error) =>
        uiBind = view.uiError?[attr] || view.ui?[attr]
        return unless uiBind?
        uiBind.toggleClass('input-validation-error', true) if uiBind
        $item = @ensureValidationSummaryItem attr, error
        $item.toggleClass "hide", false

    for key,input of @self.ui
      input.on 'change',@inputChanged if input.hasClass 'input-date'
      input.on 'blur',@inputChanged unless input.hasClass 'input-date'
      input.on 'keypress',@inputChangedCheck

  unconfigureValidation: =>
    Meshweaver.Validation.unbind @self

  onValidated: (isValid, model, errors) =>
    $validationSummary = @self.$('.validation-summary').first()
    showErrors = !isValid and
      $("ul > li", $validationSummary).not(".hide").length > 0
    $validationSummary.toggleClass 'validation-summary-valid', !showErrors
    $validationSummary.toggleClass 'validation-summary-errors', showErrors

  persistModel: =>
    changes = @self.model.changedAttributes()
    return unless changes
    return unless @self.model.isValid(true)
    @setStateToSaving()
    @self.model.save null,
      error: (response, xhr, options) =>
        @setStateToError xhr.responseJSON
      success: =>
        @setStateToSuccess()
        return unless @self.changeEventsOn
        for key,value of changes
          fireChangeEvent = _(@self.changeEventsOn).any (attributeName) ->
            attributeName == key
          if fireChangeEvent
            @self.model.trigger "change:#{key}",@self.model
      silent: true

  inputChangedCheck: (e) ->
    return if e.target.tagName.toLowerCase() == 'textarea'
    code = if e.keyCode then e.keyCode else e.which
    return if code != 13
    @inputChanged(e)

  inputChanged: (e) =>
    @self.model.set @modelFromInputs()
    @self.trigger 'input-change', e

    if !@self.model.isNew() and @options.saveExistingOnChange
      @persistModel()
      return

    elMatcher = (match) ->
      $(e.currentTarget).is match
    uiFilter = (uiPair) ->
      _.any uiPair[1], elMatcher
    matchedUi = _.chain(this.self.ui).pairs().filter(uiFilter).first().value()
    return unless matchedUi
    update = {}
    update[matchedUi[0]] = @valueFromInput(matchedUi[1])
    @self.model.validate(update)

  modelFromInputs: =>
    @proposedModel = {}
    for key,value of @self.ui
      @proposedModel[key] = @valueFromInput(value)
    @proposedModel

  valueFromInput: (input) ->
    el = if input.is(':radio') then input.filter(':checked') else input
    val = el.val()
    return undefined if val == ''
    if el.hasClass 'input-date'
      return moment(val).utc().format "YYYY-MM-DD[T]HH:mm:ss[Z]"
    if el.hasClass('input-numeric') or input.is('input[type=number]')
      output = Number(val) if not isNaN(parseFloat(val)) and isFinite(val)
      output ?= Number.NaN
      return output
    return val

  clearInputs: =>
    for key,value of @self.ui
      value.val("")

  ensureValidationSummaryItem: (key, error) =>
    $validationSummary = @self.$('.validation-summary').first()
    $item = $('ul', $validationSummary).find("." + key)
    unless $item.length
      $item = $(document.createElement "li")
        .addClass(key)
        .addClass("hide")
        .appendTo($('ul', $validationSummary))
    $item.text if error then error else ""
    $item

  # coffeelint: disable=max_line_length
  rowSuccessTemplate: _.template '''<div class="alert alert-fixed alert-success alert-thin fade in"><span class="icon-stack"><i class="icon-circle-blank icon-stack-base"></i><i class="icon-thumbs-up"></i></span> <%= data.text %></div>'''
  rowInfoTemplate: _.template '''<div class="alert alert-fixed alert-info alert-thin fade in"><%= data.text %></div>'''
  rowErrorTemplate: _.template '''<div class="alert alert-error alert-thin fade in"><%= data.text %></div>'''
  # coffeelint: enable=max_line_length

  setStatusRowClass: (rowClass) =>
    @statusRowClass = rowClass

  clearStatus: =>
    @self.$(@statusRowClass + ' .alert').alert('close')

  setStateToSaving: =>
    @self.$(@statusRowClass).html @rowInfoTemplate data:
      text: 'Saving'

  setStateToSuccess: =>
    @self.$(@statusRowClass).html @rowSuccessTemplate data:
      text: 'Successfully Saved'
    setTimeout @clearStatus, 3000

  setStateToError: (response) =>
    response ||= {}
    modelState = response.modelState ||= []
    _.each modelState, (errors, attr) =>
      errors ||= []
      return unless errors[0]?
      el = _.result @self.ui, attr
      return unless el?
      el.toggleClass 'input-validation-error', true
      $item = @ensureValidationSummaryItem attr, errors[0]
      $item.toggleClass "hide", false

    $validationSummary = @self.$('.validation-summary').first()
    $validationSummary.toggleClass 'validation-summary-valid', false
    $validationSummary.toggleClass 'validation-summary-errors', true
    @

