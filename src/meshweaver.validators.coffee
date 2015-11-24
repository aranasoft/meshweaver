# Custom Validators for Backbone.Validation
# Arana Software 2013-2015

messages = Backbone.Validation.messages

isNumber = (value) ->
  return _.isNumber(value) or (_.isString(value) and value.match(@messages.number))

_.extend Backbone.Validation.validators,
  min: (value, attr, minValue, model, computed) ->
    minVal =
      if _.isFunction(minValue)
        minValue.call(model, value, attr, computed)
      else minValue
    return if isNumber(value) and value >= minVal
    @.format messages.min, @.formatLabel(attr, model), minVal

  max: (value, attr, maxValue, model, computed) ->
    maxVal =
      if _.isFunction(maxValue)
        maxValue.call(model, value, attr, computed)
      else maxValue
    return if isNumber(value) and value <= maxVal
    @.format messages.max, @.formatLabel(attr, model), maxVal

  range: (value, attr, range, model, computed) ->
    rangeVal =
      if _.isFunction(range)
        range.call(model, value, attr, computed)
      else range
    return if isNumber(value) and value >= rangeVal[0] and value <= rangeVal[1]
    @.format messages.range, @.formatLabel(attr, model), rangeVal[0], rangeVal[1]

  length: (value, attr, length, model, computed) ->
    lengthVal =
      if _.isFunction(length)
        length.call(model, value, attr, computed)
      else length
    return if _.isString(value) and value.length == lengthVal
    @.format messages.length, @.formatLabel(attr, model), lengthVal

  minLength: (value, attr, minLength, model, computed) ->
    minLengthVal =
      if _.isFunction(minLength)
        minLength.call(model, value, attr, computed)
      else minLength
    return if _.isString(value) and value.length >= minLengthVal
    @.format messages.minLength, @.formatLabel(attr, model), minLengthVal

  maxLength: (value, attr, maxLength, model, computed) ->
    maxLengthVal =
      if _.isFunction(maxLength)
        maxLength.call(model, value, attr, computed)
      else maxLength
    return if _.isString(value) and value.length <= maxLengthVal
    @.format messages.maxLength, @.formatLabel(attr, model), maxLengthVal

  rangeLength: (value, attr, range, model, computed) ->
    rangeVal =
      if _.isFunction(range)
        range.call(model, value, attr, computed)
      else range
    return if _.isString(value) and value.length >= rangeVal[0] and value.length <= rangeVal[1]
    @.format messages.rangeLength, @.formatLabel(attr, model), rangeVal[0], rangeVal[1]

  pattern: (value, attr, pattern, model, computed) ->
    patternVal =
      if _.isFunction(pattern)
        pattern.call(model, value, attr, computed)
      else pattern
    return if hasValue(value) and value.toString().match(defaultPatterns[pattern] || pattern)
    @.format messages[pattern] || messages.inlinePattern, @.formatLabel(attr, model), patternVal

_.extend Backbone.Model.prototype, Backbone.Validation.mixin