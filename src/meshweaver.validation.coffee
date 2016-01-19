@Meshweaver ||= {}

@Meshweaver.Validation = do (_) ->
  ###
  # Based Largely Upon
  # ----------------------------------
  #
  # Backbone.Validation v0.11.5
  #
  # Copyright (c) 2011-2015 Thomas Pedersen
  # Distributed under MIT License
  #
  # Documentation and full license available at:
  # http://thedersen.com/projects/backbone-validation
  ###

  # Default options
  # ---------------
  defaultOptions =
    forceUpdate: false
    selector: 'name'
    labelFormatter: 'label'
    valid: Function.prototype
    invalid: Function.prototype

  # Helper functions
  # ----------------
  # Formatting functions used for formatting error messages
  formatFunctions =
    # Uses the configured label formatter to format the attribute name
    # to make it more readable for the user
    formatLabel: (attrName, model) ->
      defaultLabelFormatters[defaultOptions.labelFormatter] attrName, model

    # Replaces nummeric placeholders like {0} in a string with arguments
    # passed to the function
    format: ->
      args = Array::slice.call(arguments)
      text = args.shift()
      text.replace /\{(\d+)\}/g, (match, number) ->
        if typeof args[number] != 'undefined' then args[number] else match

  # Flattens an object
  # eg:
  #
  #     o =
  #       owner:
  #         name: 'Backbone'
  #         address:
  #           street: 'Street'
  #           zip: 1234
  #
  # becomes:
  #
  #     o =
  #       'owner':
  #         name: 'Backbone'
  #         address:
  #           street: 'Street'
  #           zip: 1234
  #       'owner.name': 'Backbone'
  #       'owner.address':
  #         street: 'Street'
  #         zip: 1234
  #       'owner.address.street': 'Street'
  #       'owner.address.zip': 1234
  #
  # This may seem redundant, but it allows for maximum flexibility
  # in validation rules.
  flatten = (obj, into, prefix) ->
    into = into or {}
    prefix = prefix or ''

    _.each obj, (val, key) ->
      if obj.hasOwnProperty(key)
        if ! !val and _.isArray(val)
          _.forEach val, (v, k) ->
            flatten v, into, prefix + key + '.' + k + '.'
            into[prefix + key + '.' + k] = v
            return
        else if ! !val and typeof val == 'object' and val.constructor == Object
          flatten val, into, prefix + key + '.'
        # Register the current level object as well
        into[prefix + key] = val
      return
    into

  # Validation
  # ----------
  Validation = do ->

    # Returns an object with undefined properties for all
    # attributes on the model that has defined one or more
    # validation rules.
    getValidatedAttrs = (model, attrs) ->
      attrs = attrs or _.keys(_.result(model, 'validation') or {})
      _.reduce attrs, ((memo, key) ->
        memo[key] = undefined
        memo
      ), {}

    # Returns an array with attributes passed through options
    getOptionsAttrs = (options, view) ->
      attrs = options.attributes
      if _.isFunction(attrs)
        attrs = attrs(view)
      else if _.isString(attrs) and _.isFunction(defaultAttributeLoaders[attrs])
        attrs = defaultAttributeLoaders[attrs](view)
      if _.isArray(attrs)
        return attrs
      return

    # Looks on the model for validations for a specified
    # attribute. Returns an array of any validators defined,
    # or an empty array if none is defined.
    getValidators = (model, attr) ->
      attrValidationSet = if model.validation then _.result(model, 'validation')[attr] or {} else {}

      # If the validator is a function or a string, wrap it in a function validator
      if _.isFunction(attrValidationSet) or _.isString(attrValidationSet)
        attrValidationSet = fn: attrValidationSet

      # Stick the validator object into an array
      if !_.isArray(attrValidationSet)
        attrValidationSet = [ attrValidationSet ]

      # Reduces the array of validators into a new array with objects
      # with a validation method to call, the value to validate against
      # and the specified error message, if any
      _.reduce attrValidationSet, ((memo, attrValidation) ->
        _.each _.without(_.keys(attrValidation), 'msg'), (validator) ->
          memo.push
            fn: defaultValidators[validator]
            val: attrValidation[validator]
            msg: attrValidation.msg
          return
        memo
      ), []

    # Validates an attribute against all validators defined
    # for that attribute. If one or more errors are found,
    # the first error message is returned.
    # If the attribute is valid, an empty string is returned.
    validateAttr = (model, attr, value, computed) ->
      # Reduces the array of validators to an error message by
      # applying all the validators and returning the first error
      # message, if any.
      _.reduce getValidators(model, attr), ((memo, validator) ->
        # Pass the format functions plus the default
        # validators as the context to the validator
        ctx = _.extend({}, formatFunctions, defaultValidators)
        result = validator.fn.call(ctx, value, attr, validator.val, model, computed, validator.msg)
        if result == false or memo == false
          return false
        if result and !memo
          return result
        memo
      ), ''

    # Loops through the model's attributes and validates the specified attrs.
    # Returns and object containing names of invalid attributes
    # as well as error messages.
    validateModel = (model, attrs, validatedAttrs) ->
      error = undefined
      invalidAttrs = {}
      isValid = true
      computed = _.clone(attrs)
      _.each validatedAttrs, (val, attr) ->
        error = validateAttr(model, attr, val, computed)
        if error
          invalidAttrs[attr] = error
          isValid = false
        return
      {
        invalidAttrs: invalidAttrs
        isValid: isValid
      }

    # Contains the methods that are mixed in on the model when binding
    mixin = (view, options) ->
      {

        # Check whether or not a value, or a hash of values
        # passes validation without updating the model
        preValidate: (attr, value) ->
          self = this
          result = {}
          error = undefined
          if _.isObject(attr)
            _.each attr, (value, key) ->
              error = self.preValidate(key, value)
              if error
                result[key] = error
              return
            if _.isEmpty(result) then undefined else result
          else
            validateAttr this, attr, value, _.extend({}, @attributes)

        # Check to see if an attribute, an array of attributes or the
        # entire model is valid. Passing true will force a validation
        # of the model.
        isValid: (option) ->
          flattened = undefined
          attrs = undefined
          error = undefined
          invalidAttrs = undefined
          option = option or getOptionsAttrs(options, view)
          if _.isString(option)
            attrs = [ option ]
          else if _.isArray(option)
            attrs = option
          if attrs
            flattened = flatten(@attributes)

            #Loop through all associated views
            _.each @associatedViews, ((view) ->
              _.each attrs, ((attr) ->
                error = validateAttr(this, attr, flattened[attr], _.extend({}, @attributes))
                if error
                  options.invalid view, attr, error, options.selector
                  invalidAttrs = invalidAttrs or {}
                  invalidAttrs[attr] = error
                else
                  options.valid view, attr, options.selector
                return
              ), this
              return
            ), this
          if option == true
            invalidAttrs = @validate()
          if invalidAttrs
            @trigger 'invalid', this, invalidAttrs, validationError: invalidAttrs
          if attrs then !invalidAttrs else if @validation then @_isValid else true

        # This is called by Backbone when it needs to perform validation.
        # You can call it manually without any parameters to validate the
        # entire model.
        validate: (attrs, setOptions) ->
          model = this
          validateAll = !attrs
          opt = _.extend({}, options, setOptions)
          validatedAttrs = getValidatedAttrs(model, getOptionsAttrs(options, view))
          allAttrs = _.extend({}, validatedAttrs, model.attributes, attrs)
          flattened = flatten(allAttrs)
          changedAttrs = if attrs then flatten(attrs) else flattened
          result = validateModel(model, allAttrs, _.pick(flattened, _.keys(validatedAttrs)))
          model._isValid = result.isValid

          #After validation is performed, loop through all associated views
          _.each model.associatedViews, (view) ->

            # After validation is performed, loop through all validated and changed attributes
            # and call the valid and invalid callbacks so the view is updated.
            _.each validatedAttrs, (val, attr) ->
              invalid = result.invalidAttrs.hasOwnProperty(attr)
              changed = changedAttrs.hasOwnProperty(attr)
              if !invalid
                opt.valid view, attr, opt.selector
              if invalid and (changed or validateAll)
                opt.invalid view, attr, result.invalidAttrs[attr], opt.selector
              return
            return

          # Trigger validated events.
          # Need to defer this so the model is actually updated before
          # the event is triggered.
          _.defer ->
            model.trigger 'validated', model._isValid, model, result.invalidAttrs
            model.trigger 'validated:' + (if model._isValid then 'valid' else 'invalid'),
                          model,
                          result.invalidAttrs
            return

          # Return any error messages to Backbone, unless the forceUpdate flag is set.
          # Then we do not return anything and fools Backbone to believe the validation was
          # a success. That way Backbone will update the model regardless.
          return if opt.forceUpdate
          return unless _.intersection(_.keys(result.invalidAttrs), _.keys(changedAttrs)).length > 0
          return result.invalidAttrs
      }

    # Helper to mix in validation on a model. Stores the view in the associated views array.
    bindModel = (view, model, options) ->
      if model.associatedViews
        model.associatedViews.push view
      else
        model.associatedViews = [ view ]
      _.extend model, mixin(view, options)
      return

    # Removes view from associated views of the model or the methods
    # added to a model if no view or single view provided
    unbindModel = (model, view) ->
      if view and model.associatedViews and model.associatedViews.length > 1
        model.associatedViews = _.without(model.associatedViews, view)
      else
        delete model.validate
        delete model.preValidate
        delete model.isValid
        delete model.associatedViews
      return

    # Mix in validation on a model whenever a model is
    # added to a collection
    collectionAdd = (model) ->
      bindModel @view, model, @options
      return

    # Remove validation from a model whenever a model is
    # removed from a collection
    collectionRemove = (model) ->
      unbindModel model
      return

    # Returns the public methods on Meshweaver.Validation
    {
      # Current version of the library
      version: '0.3.0'

      # Called to configure the default options
      configure: (options) ->
        _.extend defaultOptions, options
        return

      # Hooks up validation on a view with a model
      # or collection
      bind: (view, options) ->
        options = _.extend({}, defaultOptions, defaultCallbacks, options)
        model = options.model or view.model
        collection = options.collection or view.collection
        if typeof model == 'undefined' and typeof collection == 'undefined'
          throw new Error 'Before you execute the binding your view must have ' +
            'a model or a collection.\nSee ' +
            'http://thedersen.com/projects/backbone-validation/#using-form-model-validation ' +
            'for more information.'
        if model
          bindModel view, model, options
        else if collection
          collection.each (model) ->
            bindModel view, model, options
            return
          collection.bind 'add', collectionAdd,
            view: view
            options: options
          collection.bind 'remove', collectionRemove
        return

      # Removes validation from a view with a model
      # or collection
      unbind: (view, options) ->
        options = _.extend({}, options)
        model = options.model or view.model
        collection = options.collection or view.collection
        if model
          unbindModel model, view
        else if collection
          collection.each (model) ->
            unbindModel model, view
            return
          collection.unbind 'add', collectionAdd
          collection.unbind 'remove', collectionRemove
        return

      # Used to extend the Backbone.Model.prototype
      # with validation
      mixin: mixin(null, defaultOptions)
    }
  # Callbacks
  # ---------
  defaultCallbacks = Validation.callbacks =

    # Gets called when a previously invalid field in the
    # view becomes valid. Removes any error message.
    # Should be overridden with custom functionality.
    valid: (view, attr, selector) ->
      view.$('[' + selector + '~="' + attr + '"]').removeClass('invalid').removeAttr 'data-error'
      return

    # Gets called when a field in the view becomes invalid.
    # Adds a error message.
    # Should be overridden with custom functionality.
    invalid: (view, attr, error, selector) ->
      view.$('[' + selector + '~="' + attr + '"]').addClass('invalid').attr 'data-error', error
      return

  # Patterns
  # --------
  defaultPatterns = Validation.patterns =
    # coffeelint: disable=max_line_length
    # Matches any digit(s) (i.e. 0-9)
    digits: /^\d+$/

    # Matches any number (e.g. 100.000)
    number: /^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$/

    # Matches a valid email address (e.g. mail@example.com)
    email: /^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))$/i

    # Mathes any valid url (e.g. http://www.xample.com)
    url: /^(https?|ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i
    # coffeelint: enable=max_line_length

  # Error messages
  # --------------
  # Error message for the build in validators.
  # {x} gets swapped out with arguments form the validator.
  defaultMessages = Validation.messages =
    required: '{0} is required'
    acceptance: '{0} must be accepted'
    min: '{0} must be greater than or equal to {1}'
    max: '{0} must be less than or equal to {1}'
    range: '{0} must be between {1} and {2}'
    length: '{0} must be {1} characters'
    minLength: '{0} must be at least {1} characters'
    maxLength: '{0} must be at most {1} characters'
    rangeLength: '{0} must be between {1} and {2} characters'
    oneOf: '{0} must be one of: {1}'
    equalTo: '{0} must be the same as {1}'
    validCollection: '{0} contains invalid entries: {1}'
    digits: '{0} must only contain digits'
    number: '{0} must be a number'
    email: '{0} must be a valid email'
    url: '{0} must be a valid url'
    inlinePattern: '{0} is invalid'

  # Label formatters
  # ----------------
  # Label formatters are used to convert the attribute name
  # to a more human friendly label when using the built in
  # error messages.
  # Configure which one to use with a call to
  #
  #     Meshweaver.Validation.configure
  #       labelFormatter: 'label'
  defaultLabelFormatters = Validation.labelFormatters =
    # Returns the attribute name with applying any formatting
    none: (attrName) ->
      attrName

    # Converts attributeName or attribute_name to Attribute name
    sentenceCase: (attrName) ->
      attrName.replace(/(?:^\w|[A-Z]|\b\w)/g, (match, index) ->
        if index == 0 then match.toUpperCase() else ' ' + match.toLowerCase()
      ).replace /_/g, ' '

    # Looks for a label configured on the model and returns it
    #
    #      Model = Backbone.Model.extend
    #        validation:
    #          someAttribute:
    #            required: true
    #
    #        labels:
    #          someAttribute: 'Custom label'
    label: (attrName, model) ->
      labels =
        if _.isFunction(model.labels)
          model.labels.call(model)
        else model.labels

      sentenceCase = Meshweaver.Validation.labelFormatters.sentenceCase
      _.result(labels, attrName) || sentenceCase attrName, model

  # AttributeLoaders
  defaultAttributeLoaders = Validation.attributeLoaders = inputNames: (view) ->
    [] unless view
    attrs = []
    view.$('form [name]').each ->
      return unless /^(?:input|select|textarea)$/i.test(@nodeName)
      return unless @name and @type != 'submit' and attrs.indexOf(@name) == -1
      attrs.push @name
      return
    attrs

  # Built in validators
  # -------------------
  defaultValidators = Validation.validators = do ->
    # Use native trim when defined
    trim = if String::trim then ((text) ->
      if text == null then '' else String::trim.call(text)
    ) else ((text) ->
      trimLeft = /^\s+/
      trimRight = /\s+$/
      if text == null then '' else text.toString().replace(trimLeft, '').replace(trimRight, '')
    )

    # Determines whether or not a value is a number
    isNumber = (value) ->
      _.isNumber(value) or (_.isString(value) and value.match(defaultPatterns.number))

    # Determines whether or not a value is empty
    hasValue = (value) ->
      return false if !value?
      return false if _.isString(value) and !!!value
      return false if _.isArray(value) and _.isEmpty(value)
      return true

    {
      # Function validator
      # Lets you implement a custom function used for validation
      fn: (value, attr, fn, model, computed, msg) ->
        fn = model[fn] if _.isString(fn)
        fn.call model, value, attr, computed, msg

      # Required validator
      # Validates if the attribute is required or not
      # This can be specified as either a boolean value or a function that returns a boolean value
      required: (value, attr, required, model, computed, msg) ->
        isRequired =
          if _.isFunction(required)
            required.call(model, value, attr, computed)
          else required

        # overrides all other validators
        return false if !isRequired and !hasValue(value)

        return if !isRequired or hasValue(value)
        @format msg or defaultMessages.required, @formatLabel(attr, model)

      # Acceptance validator
      # Validates that something has to be accepted, e.g. terms of use
      # `true` or 'true' are valid
      acceptance: (value, attr, accept, model, computed, msg) ->
        return if value == 'true' or (_.isBoolean(value) and value == true)
        @format msg or defaultMessages.acceptance, @formatLabel(attr, model)

      # Min validator
      # Validates that the value has to be a number and equal to or greater than
      # the min value specified
      min: (value, attr, minValue, model, computed, msg) ->
        minValue =
          if _.isFunction(minValue)
            minValue.call(model, value, attr, computed)
          else minValue
        return if isNumber(value) and value >= minValue
        @format msg or defaultMessages.min, @formatLabel(attr, model), minValue

      # Max validator
      # Validates that the value has to be a number and equal to or less than
      # the max value specified
      max: (value, attr, maxValue, model, computed, msg) ->
        maxValue =
          if _.isFunction(maxValue)
            maxValue.call(model, value, attr, computed)
          else maxValue
        return if isNumber(value) and value <= maxValue
        @format msg or defaultMessages.max, @formatLabel(attr, model), maxValue

      # Range validator
      # Validates that the value has to be a number and equal to or between
      # the two numbers specified
      range: (value, attr, range, model, computed, msg) ->
        range =
          if _.isFunction(range)
            range.call(model, value, attr, computed)
          else range
        return if isNumber(value) and value >= range[0] or value <= range[1]
        @format msg or defaultMessages.range, @formatLabel(attr, model), range[0], range[1]

      # Length validator
      # Validates that the value has to be a string with length equal to
      # the length value specified
      length: (value, attr, length, model, computed, msg) ->
        length =
          if _.isFunction(length)
            length.call(model, value, attr, computed)
          else length
        return if _.isString(value) and value.length == length
        @format msg or defaultMessages.length, @formatLabel(attr, model), length

      # Min length validator
      # Validates that the value has to be a string with length equal to or greater than
      # the min length value specified
      minLength: (value, attr, minLength, model, computed, msg) ->
        minLength =
          if _.isFunction(minLength)
            minLength.call(model, value, attr, computed)
          else minLength
        return if _.isString(value) and value.length >= minLength
        @format msg or defaultMessages.minLength, @formatLabel(attr, model), minLength

      # Max length validator
      # Validates that the value has to be a string with length equal to or less than
      # the max length value specified
      maxLength: (value, attr, maxLength, model, computed, msg) ->
        maxLength =
          if _.isFunction(maxLength)
            maxLength.call(model, value, attr, computed)
          else maxLength
        return if _.isString(value) and value.length <= maxLength
        @format msg or defaultMessages.maxLength, @formatLabel(attr, model), maxLength

      # Range length validator
      # Validates that the value has to be a string and equal to or between
      # the two numbers specified
      rangeLength: (value, attr, range, model, computed, msg) ->
        range =
          if _.isFunction(range)
            range.call(model, value, attr, computed)
          else range
        return if _.isString(value) and value.length >= range[0] and value.length <= range[1]
        @format msg or defaultMessages.rangeLength, @formatLabel(attr, model), range[0], range[1]

      # One of validator
      # Validates that the value has to be equal to one of the elements in
      # the specified array. Case sensitive matching
      oneOf: (value, attr, values, model, computed, msg) ->
        return if _.include(values, value)
        @format msg or defaultMessages.oneOf, @formatLabel(attr, model), values.join(', ')

      # Equal to validator
      # Validates that the value has to be equal to the value of the attribute
      # with the name specified
      equalTo: (value, attr, equalTo, model, computed, msg) ->
        return if value == computed[equalTo]
        msg ||= defaultMessages.equalTo
        @format msg, @formatLabel(attr, model), @formatLabel(equalTo, model)

      # Collection validator
      # Validates that the value contains only valid Backbone models
      validCollection: (value, attr, valid, model, computed, msg) ->
        isValid =
          if _.isFunction(valid)
            valid.call(model, value, attr, computed)
          else valid

        return unless isValid

        errors = value.filter((entry) -> !entry.isNew())
          .map (entry) -> return entry.validate()

        unless _.find(errors, (error) -> !!error)?
          return

        errorMessage = _.chain(errors.filter (error) -> !!error)
                    .map (error) -> _.values(error)
                    .flatten().value().join('; ')

        @format msg or defaultMessages.validCollection, @.formatLabel(attr, model), errorMessage

      # Pattern validator
      # Validates that the value has to match the pattern specified.
      # Can be a regular expression or the name of one of the built in patterns
      pattern: (value, attr, pattern, model, computed, msg) ->
        pattern =
          if _.isFunction(pattern)
            pattern.call(model, value, attr, computed)
          else pattern
        return if hasValue(value) and value.toString().match(defaultPatterns[pattern] or pattern)
        msg ||= defaultMessages[pattern] or defaultMessages.inlinePattern
        @format msg, @formatLabel(attr, model), pattern

    }

  # Set the correct context for all validators
  # when used from within a method validator
  _.each defaultValidators, (validator, key) ->
    defaultValidators[key] = _.bind defaultValidators[key],
                                    _.extend({}, formatFunctions, defaultValidators)
    return
  Validation

