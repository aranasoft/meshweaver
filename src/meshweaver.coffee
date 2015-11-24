# Utilities for Marionette views
# Arana Software 2013
class @Meshweaver
  constructor: (self, options) ->
    @self = self
    options ||= {}
    @saveExistingOnChange = options.saveExistingOnChange ?= true
    @requireUiBinding = options.requireUiBinding ?= true
    @statusRowClass = '.row-status'

  configureValidation: =>
    Backbone.Validation.bind @self,
      valid: (view, attr) =>
        uiBind = view.ui[attr]
        return unless uiBind or not @requireUIBinding
        uiBind.toggleClass('input-validation-error', false) if uiBind
        $item = @ensureValidationSummaryItem attr
        $item.toggleClass "hide", true
      invalid: (view, attr, error) =>
        uiBind = view.ui[attr]
        return unless uiBind or not @requireUIBinding
        uiBind.toggleClass('input-validation-error', true) if uiBind
        $item = @ensureValidationSummaryItem attr, error
        $item.toggleClass "hide", false

    for key,input of @self.ui
      input.on 'change',@inputChanged if input.hasClass 'input-date'
      input.on 'blur',@inputChanged unless input.hasClass 'input-date'
      input.on 'keypress',@inputChangedCheck

  unconfigureValidation: =>
    Backbone.Validation.unbind @self

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
    @self.model.set @modelFromInputs(),
      silent: true

    @self.trigger 'input-change', e

    if !@self.model.isNew() and @saveExistingOnChange
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
    val = input.val()
    return undefined if val == ''
    if input.hasClass 'input-date'
      return moment(val).utc().format "YYYY-MM-DD[T]HH:mm:ss[Z]"
    if input.hasClass('input-numeric') or input.is('input[type=number]')
      output = Number(val) if not isNaN(parseFloat(val)) and isFinite(val)
      output ?= Number.NaN
      return output
    return val

  clearInputs: =>
    for key,value of @self.ui
      value.val("")

  ensureValidationSummaryItem: (key, error) =>
    $validationSummary = @self.$('.validation-summary').first()
    $item = $('ul', $validationSummary).find("."+key)
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
      return unless @self.ui and @self.ui[attr]?
      @self.ui[attr].toggleClass 'input-validation-error', true
      $item = @ensureValidationSummaryItem attr, errors[0]
      $item.toggleClass "hide", false

    $validationSummary = @self.$('.validation-summary').first()
    $validationSummary.toggleClass 'validation-summary-valid', false
    $validationSummary.toggleClass 'validation-summary-errors', true
    @

