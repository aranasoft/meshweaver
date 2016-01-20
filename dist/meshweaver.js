/**
 * meshweaver v0.3.0
 * @copyright 2013-2016 Arana Software <info@aranasoft.com>. https://github.com/aranasoft/meshweaver
 * @license BSD-3-Clause
 */
(function() {
  var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  this.Meshweaver || (this.Meshweaver = {});

  this.Meshweaver.ValidatedView = (function() {
    function ValidatedView(self, options) {
      this.setStateToError = bind(this.setStateToError, this);
      this.setStateToSuccess = bind(this.setStateToSuccess, this);
      this.setStateToSaving = bind(this.setStateToSaving, this);
      this.clearStatus = bind(this.clearStatus, this);
      this.setStatusRowClass = bind(this.setStatusRowClass, this);
      this.ensureValidationSummaryItem = bind(this.ensureValidationSummaryItem, this);
      this.clearInputs = bind(this.clearInputs, this);
      this.modelFromInputs = bind(this.modelFromInputs, this);
      this.inputChanged = bind(this.inputChanged, this);
      this.persistModel = bind(this.persistModel, this);
      this.onValidated = bind(this.onValidated, this);
      this.unconfigureValidation = bind(this.unconfigureValidation, this);
      this.configureValidation = bind(this.configureValidation, this);
      this.self = self;
      options || (options = {});
      this.saveExistingOnChange = options.saveExistingOnChange != null ? options.saveExistingOnChange : options.saveExistingOnChange = true;
      this.requireUiBinding = options.requireUiBinding != null ? options.requireUiBinding : options.requireUiBinding = true;
      this.statusRowClass = '.row-status';
    }

    ValidatedView.prototype.bindUIElements = function() {
      this._bindUIElements();
      this._bindUIErrorElements();
      _.invoke(this._behaviors, this._bindUIElements);
      _.invoke(this._behaviors, this._bindUIErrorElements);
    };

    ValidatedView.prototype._bindUIErrorElements = function() {
      var bindings;
      if (!this.uiError) {
        return;
      }
      if (!this._uiErrorBindings) {
        this._uiErrorBindings = this.uiError;
      }
      bindings = _.result(this, '_uiErrorBindings');
      this.uiError = {};
      _.each(bindings, (function(selector, key) {
        this.uiError[key] = this.$(selector);
      }), this);
    };

    ValidatedView.prototype.unbindUIElements = function() {
      this._unbindUIElements();
      this._unbindUIErrorElements();
      _.invoke(this._behaviors, this._unbindUIElements);
      _.invoke(this._behaviors, this._unbindUIErrorElements);
    };

    ValidatedView.prototype._unbindUIErrorElements = function() {
      if (!this.uiError || !this._uiErrorBindings) {
        return;
      }
      _.each(this.uiError, (function($el, name) {
        delete this.uiError[name];
      }), this);
      this.uiError = this._uiErrorBindings;
      delete this._uiErrorBindings;
    };

    ValidatedView.prototype.configureValidation = function() {
      var input, key, ref, results;
      Meshweaver.Validation.bind(this.self, {
        valid: (function(_this) {
          return function(view, attr) {
            var $item, ref, ref1, uiBind;
            if (_this.requireUIBinding) {
              return;
            }
            uiBind = ((ref = view.uiError) != null ? ref[attr] : void 0) || ((ref1 = view.ui) != null ? ref1[attr] : void 0);
            if (uiBind == null) {
              return;
            }
            if (uiBind) {
              uiBind.toggleClass('input-validation-error', false);
            }
            $item = _this.ensureValidationSummaryItem(attr);
            return $item.toggleClass("hide", true);
          };
        })(this),
        invalid: (function(_this) {
          return function(view, attr, error) {
            var $item, ref, ref1, uiBind;
            if (_this.requireUIBinding) {
              return;
            }
            uiBind = ((ref = view.uiError) != null ? ref[attr] : void 0) || ((ref1 = view.ui) != null ? ref1[attr] : void 0);
            if (uiBind == null) {
              return;
            }
            if (uiBind) {
              uiBind.toggleClass('input-validation-error', true);
            }
            $item = _this.ensureValidationSummaryItem(attr, error);
            return $item.toggleClass("hide", false);
          };
        })(this)
      });
      ref = this.self.ui;
      results = [];
      for (key in ref) {
        input = ref[key];
        if (input.hasClass('input-date')) {
          input.on('change', this.inputChanged);
        }
        if (!input.hasClass('input-date')) {
          input.on('blur', this.inputChanged);
        }
        results.push(input.on('keypress', this.inputChangedCheck));
      }
      return results;
    };

    ValidatedView.prototype.unconfigureValidation = function() {
      return Meshweaver.Validation.unbind(this.self);
    };

    ValidatedView.prototype.onValidated = function(isValid, model, errors) {
      var $validationSummary, showErrors;
      $validationSummary = this.self.$('.validation-summary').first();
      showErrors = !isValid && $("ul > li", $validationSummary).not(".hide").length > 0;
      $validationSummary.toggleClass('validation-summary-valid', !showErrors);
      return $validationSummary.toggleClass('validation-summary-errors', showErrors);
    };

    ValidatedView.prototype.persistModel = function() {
      var changes;
      changes = this.self.model.changedAttributes();
      if (!changes) {
        return;
      }
      if (!this.self.model.isValid(true)) {
        return;
      }
      this.setStateToSaving();
      return this.self.model.save(null, {
        error: (function(_this) {
          return function(response, xhr, options) {
            return _this.setStateToError(xhr.responseJSON);
          };
        })(this),
        success: (function(_this) {
          return function() {
            var fireChangeEvent, key, results, value;
            _this.setStateToSuccess();
            if (!_this.self.changeEventsOn) {
              return;
            }
            results = [];
            for (key in changes) {
              value = changes[key];
              fireChangeEvent = _(_this.self.changeEventsOn).any(function(attributeName) {
                return attributeName === key;
              });
              if (fireChangeEvent) {
                results.push(_this.self.model.trigger("change:" + key, _this.self.model));
              } else {
                results.push(void 0);
              }
            }
            return results;
          };
        })(this),
        silent: true
      });
    };

    ValidatedView.prototype.inputChangedCheck = function(e) {
      var code;
      if (e.target.tagName.toLowerCase() === 'textarea') {
        return;
      }
      code = e.keyCode ? e.keyCode : e.which;
      if (code !== 13) {
        return;
      }
      return this.inputChanged(e);
    };

    ValidatedView.prototype.inputChanged = function(e) {
      var elMatcher, matchedUi, uiFilter, update;
      this.self.model.set(this.modelFromInputs(), {
        silent: true
      });
      this.self.trigger('input-change', e);
      if (!this.self.model.isNew() && this.saveExistingOnChange) {
        this.persistModel();
        return;
      }
      elMatcher = function(match) {
        return $(e.currentTarget).is(match);
      };
      uiFilter = function(uiPair) {
        return _.any(uiPair[1], elMatcher);
      };
      matchedUi = _.chain(this.self.ui).pairs().filter(uiFilter).first().value();
      if (!matchedUi) {
        return;
      }
      update = {};
      update[matchedUi[0]] = this.valueFromInput(matchedUi[1]);
      return this.self.model.validate(update);
    };

    ValidatedView.prototype.modelFromInputs = function() {
      var key, ref, value;
      this.proposedModel = {};
      ref = this.self.ui;
      for (key in ref) {
        value = ref[key];
        this.proposedModel[key] = this.valueFromInput(value);
      }
      return this.proposedModel;
    };

    ValidatedView.prototype.valueFromInput = function(input) {
      var el, output, val;
      el = input.is(':radio') ? input.filter(':checked') : input;
      val = el.val();
      if (val === '') {
        return void 0;
      }
      if (el.hasClass('input-date')) {
        return moment(val).utc().format("YYYY-MM-DD[T]HH:mm:ss[Z]");
      }
      if (el.hasClass('input-numeric') || input.is('input[type=number]')) {
        if (!isNaN(parseFloat(val)) && isFinite(val)) {
          output = Number(val);
        }
        if (output == null) {
          output = Number.NaN;
        }
        return output;
      }
      return val;
    };

    ValidatedView.prototype.clearInputs = function() {
      var key, ref, results, value;
      ref = this.self.ui;
      results = [];
      for (key in ref) {
        value = ref[key];
        results.push(value.val(""));
      }
      return results;
    };

    ValidatedView.prototype.ensureValidationSummaryItem = function(key, error) {
      var $item, $validationSummary;
      $validationSummary = this.self.$('.validation-summary').first();
      $item = $('ul', $validationSummary).find("." + key);
      if (!$item.length) {
        $item = $(document.createElement("li")).addClass(key).addClass("hide").appendTo($('ul', $validationSummary));
      }
      $item.text(error ? error : "");
      return $item;
    };

    ValidatedView.prototype.rowSuccessTemplate = _.template('<div class="alert alert-fixed alert-success alert-thin fade in"><span class="icon-stack"><i class="icon-circle-blank icon-stack-base"></i><i class="icon-thumbs-up"></i></span> <%= data.text %></div>');

    ValidatedView.prototype.rowInfoTemplate = _.template('<div class="alert alert-fixed alert-info alert-thin fade in"><%= data.text %></div>');

    ValidatedView.prototype.rowErrorTemplate = _.template('<div class="alert alert-error alert-thin fade in"><%= data.text %></div>');

    ValidatedView.prototype.setStatusRowClass = function(rowClass) {
      return this.statusRowClass = rowClass;
    };

    ValidatedView.prototype.clearStatus = function() {
      return this.self.$(this.statusRowClass + ' .alert').alert('close');
    };

    ValidatedView.prototype.setStateToSaving = function() {
      return this.self.$(this.statusRowClass).html(this.rowInfoTemplate({
        data: {
          text: 'Saving'
        }
      }));
    };

    ValidatedView.prototype.setStateToSuccess = function() {
      this.self.$(this.statusRowClass).html(this.rowSuccessTemplate({
        data: {
          text: 'Successfully Saved'
        }
      }));
      return setTimeout(this.clearStatus, 3000);
    };

    ValidatedView.prototype.setStateToError = function(response) {
      var $validationSummary, modelState;
      response || (response = {});
      modelState = response.modelState || (response.modelState = []);
      _.each(modelState, (function(_this) {
        return function(errors, attr) {
          var $item, el;
          errors || (errors = []);
          if (errors[0] == null) {
            return;
          }
          el = _.result(_this.self.ui, attr);
          if (el == null) {
            return;
          }
          el.toggleClass('input-validation-error', true);
          $item = _this.ensureValidationSummaryItem(attr, errors[0]);
          return $item.toggleClass("hide", false);
        };
      })(this));
      $validationSummary = this.self.$('.validation-summary').first();
      $validationSummary.toggleClass('validation-summary-valid', false);
      $validationSummary.toggleClass('validation-summary-errors', true);
      return this;
    };

    return ValidatedView;

  })();

}).call(this);

(function() {
  this.Meshweaver || (this.Meshweaver = {});

  this.Meshweaver.Validation = (function(_) {

    /*
     * Based Largely Upon
     * ----------------------------------
     *
     * Backbone.Validation v0.11.5
     *
     * Copyright (c) 2011-2015 Thomas Pedersen
     * Distributed under MIT License
     *
     * Documentation and full license available at:
     * http://thedersen.com/projects/backbone-validation
     */
    var Validation, defaultAttributeLoaders, defaultCallbacks, defaultLabelFormatters, defaultMessages, defaultOptions, defaultPatterns, defaultValidators, flatten, formatFunctions;
    defaultOptions = {
      forceUpdate: false,
      selector: 'name',
      labelFormatter: 'label',
      valid: Function.prototype,
      invalid: Function.prototype
    };
    formatFunctions = {
      formatLabel: function(attrName, model) {
        return defaultLabelFormatters[defaultOptions.labelFormatter](attrName, model);
      },
      format: function() {
        var args, text;
        args = Array.prototype.slice.call(arguments);
        text = args.shift();
        return text.replace(/\{(\d+)\}/g, function(match, number) {
          if (typeof args[number] !== 'undefined') {
            return args[number];
          } else {
            return match;
          }
        });
      }
    };
    flatten = function(obj, into, prefix) {
      into = into || {};
      prefix = prefix || '';
      _.each(obj, function(val, key) {
        if (obj.hasOwnProperty(key)) {
          if (!!val && _.isArray(val)) {
            _.forEach(val, function(v, k) {
              flatten(v, into, prefix + key + '.' + k + '.');
              into[prefix + key + '.' + k] = v;
            });
          } else if (!!val && typeof val === 'object' && val.constructor === Object) {
            flatten(val, into, prefix + key + '.');
          }
          into[prefix + key] = val;
        }
      });
      return into;
    };
    Validation = (function() {
      var bindModel, collectionAdd, collectionRemove, getOptionsAttrs, getValidatedAttrs, getValidators, mixin, unbindModel, validateAttr, validateModel;
      getValidatedAttrs = function(model, attrs) {
        attrs = attrs || _.keys(_.result(model, 'validation') || {});
        return _.reduce(attrs, (function(memo, key) {
          memo[key] = void 0;
          return memo;
        }), {});
      };
      getOptionsAttrs = function(options, view) {
        var attrs;
        attrs = options.attributes;
        if (_.isFunction(attrs)) {
          attrs = attrs(view);
        } else if (_.isString(attrs) && _.isFunction(defaultAttributeLoaders[attrs])) {
          attrs = defaultAttributeLoaders[attrs](view);
        }
        if (_.isArray(attrs)) {
          return attrs;
        }
      };
      getValidators = function(model, attr) {
        var attrValidationSet;
        attrValidationSet = model.validation ? _.result(model, 'validation')[attr] || {} : {};
        if (_.isFunction(attrValidationSet) || _.isString(attrValidationSet)) {
          attrValidationSet = {
            fn: attrValidationSet
          };
        }
        if (!_.isArray(attrValidationSet)) {
          attrValidationSet = [attrValidationSet];
        }
        return _.reduce(attrValidationSet, (function(memo, attrValidation) {
          _.each(_.without(_.keys(attrValidation), 'msg'), function(validator) {
            memo.push({
              fn: defaultValidators[validator],
              val: attrValidation[validator],
              msg: attrValidation.msg
            });
          });
          return memo;
        }), []);
      };
      validateAttr = function(model, attr, value, computed) {
        return _.reduce(getValidators(model, attr), (function(memo, validator) {
          var ctx, result;
          ctx = _.extend({}, formatFunctions, defaultValidators);
          result = validator.fn.call(ctx, value, attr, validator.val, model, computed, validator.msg);
          if (result === false || memo === false) {
            return false;
          }
          if (result && !memo) {
            return result;
          }
          return memo;
        }), '');
      };
      validateModel = function(model, attrs, validatedAttrs) {
        var computed, error, invalidAttrs, isValid;
        error = void 0;
        invalidAttrs = {};
        isValid = true;
        computed = _.clone(attrs);
        _.each(validatedAttrs, function(val, attr) {
          error = validateAttr(model, attr, val, computed);
          if (error) {
            invalidAttrs[attr] = error;
            isValid = false;
          }
        });
        return {
          invalidAttrs: invalidAttrs,
          isValid: isValid
        };
      };
      mixin = function(view, options) {
        return {
          preValidate: function(attr, value) {
            var error, result, self;
            self = this;
            result = {};
            error = void 0;
            if (_.isObject(attr)) {
              _.each(attr, function(value, key) {
                error = self.preValidate(key, value);
                if (error) {
                  result[key] = error;
                }
              });
              if (_.isEmpty(result)) {
                return void 0;
              } else {
                return result;
              }
            } else {
              return validateAttr(this, attr, value, _.extend({}, this.attributes));
            }
          },
          isValid: function(option) {
            var attrs, error, flattened, invalidAttrs;
            flattened = void 0;
            attrs = void 0;
            error = void 0;
            invalidAttrs = void 0;
            option = option || getOptionsAttrs(options, view);
            if (_.isString(option)) {
              attrs = [option];
            } else if (_.isArray(option)) {
              attrs = option;
            }
            if (attrs) {
              flattened = flatten(this.attributes);
              _.each(this.associatedViews, (function(view) {
                _.each(attrs, (function(attr) {
                  error = validateAttr(this, attr, flattened[attr], _.extend({}, this.attributes));
                  if (error) {
                    options.invalid(view, attr, error, options.selector);
                    invalidAttrs = invalidAttrs || {};
                    invalidAttrs[attr] = error;
                  } else {
                    options.valid(view, attr, options.selector);
                  }
                }), this);
              }), this);
            }
            if (option === true) {
              invalidAttrs = this.validate();
            }
            if (invalidAttrs) {
              this.trigger('invalid', this, invalidAttrs, {
                validationError: invalidAttrs
              });
            }
            if (attrs) {
              return !invalidAttrs;
            } else if (this.validation) {
              return this._isValid;
            } else {
              return true;
            }
          },
          validate: function(attrs, setOptions) {
            var allAttrs, changedAttrs, flattened, model, opt, result, validateAll, validatedAttrs;
            model = this;
            validateAll = !attrs;
            opt = _.extend({}, options, setOptions);
            validatedAttrs = getValidatedAttrs(model, getOptionsAttrs(options, view));
            allAttrs = _.extend({}, validatedAttrs, model.attributes, attrs);
            flattened = flatten(allAttrs);
            changedAttrs = attrs ? flatten(attrs) : flattened;
            result = validateModel(model, allAttrs, _.pick(flattened, _.keys(validatedAttrs)));
            model._isValid = result.isValid;
            _.each(model.associatedViews, function(view) {
              _.each(validatedAttrs, function(val, attr) {
                var changed, invalid;
                invalid = result.invalidAttrs.hasOwnProperty(attr);
                changed = changedAttrs.hasOwnProperty(attr);
                if (!invalid) {
                  opt.valid(view, attr, opt.selector);
                }
                if (invalid && (changed || validateAll)) {
                  opt.invalid(view, attr, result.invalidAttrs[attr], opt.selector);
                }
              });
            });
            _.defer(function() {
              model.trigger('validated', model._isValid, model, result.invalidAttrs);
              model.trigger('validated:' + (model._isValid ? 'valid' : 'invalid'), model, result.invalidAttrs);
            });
            if (opt.forceUpdate) {
              return;
            }
            if (!(_.intersection(_.keys(result.invalidAttrs), _.keys(changedAttrs)).length > 0)) {
              return;
            }
            return result.invalidAttrs;
          }
        };
      };
      bindModel = function(view, model, options) {
        if (model.associatedViews) {
          model.associatedViews.push(view);
        } else {
          model.associatedViews = [view];
        }
        _.extend(model, mixin(view, options));
      };
      unbindModel = function(model, view) {
        if (view && model.associatedViews && model.associatedViews.length > 1) {
          model.associatedViews = _.without(model.associatedViews, view);
        } else {
          delete model.validate;
          delete model.preValidate;
          delete model.isValid;
          delete model.associatedViews;
        }
      };
      collectionAdd = function(model) {
        bindModel(this.view, model, this.options);
      };
      collectionRemove = function(model) {
        unbindModel(model);
      };
      return {
        version: '0.3.0',
        configure: function(options) {
          _.extend(defaultOptions, options);
        },
        bind: function(view, options) {
          var collection, model;
          options = _.extend({}, defaultOptions, defaultCallbacks, options);
          model = options.model || view.model;
          collection = options.collection || view.collection;
          if (typeof model === 'undefined' && typeof collection === 'undefined') {
            throw new Error('Before you execute the binding your view must have ' + 'a model or a collection.\nSee ' + 'http://thedersen.com/projects/backbone-validation/#using-form-model-validation ' + 'for more information.');
          }
          if (model) {
            bindModel(view, model, options);
          } else if (collection) {
            collection.each(function(model) {
              bindModel(view, model, options);
            });
            collection.bind('add', collectionAdd, {
              view: view,
              options: options
            });
            collection.bind('remove', collectionRemove);
          }
        },
        unbind: function(view, options) {
          var collection, model;
          options = _.extend({}, options);
          model = options.model || view.model;
          collection = options.collection || view.collection;
          if (model) {
            unbindModel(model, view);
          } else if (collection) {
            collection.each(function(model) {
              unbindModel(model, view);
            });
            collection.unbind('add', collectionAdd);
            collection.unbind('remove', collectionRemove);
          }
        },
        mixin: mixin(null, defaultOptions)
      };
    })();
    defaultCallbacks = Validation.callbacks = {
      valid: function(view, attr, selector) {
        view.$('[' + selector + '~="' + attr + '"]').removeClass('invalid').removeAttr('data-error');
      },
      invalid: function(view, attr, error, selector) {
        view.$('[' + selector + '~="' + attr + '"]').addClass('invalid').attr('data-error', error);
      }
    };
    defaultPatterns = Validation.patterns = {
      digits: /^\d+$/,
      number: /^-?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$/,
      email: /^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))$/i,
      url: /^(https?|ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i
    };
    defaultMessages = Validation.messages = {
      required: '{0} is required',
      acceptance: '{0} must be accepted',
      min: '{0} must be greater than or equal to {1}',
      max: '{0} must be less than or equal to {1}',
      range: '{0} must be between {1} and {2}',
      length: '{0} must be {1} characters',
      minLength: '{0} must be at least {1} characters',
      maxLength: '{0} must be at most {1} characters',
      rangeLength: '{0} must be between {1} and {2} characters',
      oneOf: '{0} must be one of: {1}',
      equalTo: '{0} must be the same as {1}',
      notEqualTo: '{0} must not be the same as {1}',
      validCollection: '{0} contains invalid entries: {1}',
      digits: '{0} must only contain digits',
      number: '{0} must be a number',
      email: '{0} must be a valid email',
      url: '{0} must be a valid url',
      inlinePattern: '{0} is invalid'
    };
    defaultLabelFormatters = Validation.labelFormatters = {
      none: function(attrName) {
        return attrName;
      },
      sentenceCase: function(attrName) {
        return attrName.replace(/(?:^\w|[A-Z]|\b\w)/g, function(match, index) {
          if (index === 0) {
            return match.toUpperCase();
          } else {
            return ' ' + match.toLowerCase();
          }
        }).replace(/_/g, ' ');
      },
      label: function(attrName, model) {
        var labels, sentenceCase;
        labels = _.isFunction(model.labels) ? model.labels.call(model) : model.labels;
        sentenceCase = Meshweaver.Validation.labelFormatters.sentenceCase;
        return _.result(labels, attrName) || sentenceCase(attrName, model);
      }
    };
    defaultAttributeLoaders = Validation.attributeLoaders = {
      inputNames: function(view) {
        var attrs;
        if (!view) {
          [];
        }
        attrs = [];
        view.$('form [name]').each(function() {
          if (!/^(?:input|select|textarea)$/i.test(this.nodeName)) {
            return;
          }
          if (!(this.name && this.type !== 'submit' && attrs.indexOf(this.name) === -1)) {
            return;
          }
          attrs.push(this.name);
        });
        return attrs;
      }
    };
    defaultValidators = Validation.validators = (function() {
      var hasValue, isNumber, trim;
      trim = String.prototype.trim ? (function(text) {
        if (text === null) {
          return '';
        } else {
          return String.prototype.trim.call(text);
        }
      }) : (function(text) {
        var trimLeft, trimRight;
        trimLeft = /^\s+/;
        trimRight = /\s+$/;
        if (text === null) {
          return '';
        } else {
          return text.toString().replace(trimLeft, '').replace(trimRight, '');
        }
      });
      isNumber = function(value) {
        return _.isNumber(value) || (_.isString(value) && value.match(defaultPatterns.number));
      };
      hasValue = function(value) {
        if (value == null) {
          return false;
        }
        if (_.isString(value) && !!!value) {
          return false;
        }
        if (_.isArray(value) && _.isEmpty(value)) {
          return false;
        }
        return true;
      };
      return {
        fn: function(value, attr, fn, model, computed, msg) {
          if (_.isString(fn)) {
            fn = model[fn];
          }
          return fn.call(model, value, attr, computed, msg);
        },
        required: function(value, attr, required, model, computed, msg) {
          var isRequired;
          isRequired = _.isFunction(required) ? required.call(model, value, attr, computed) : required;
          if (!isRequired && !hasValue(value)) {
            return false;
          }
          if (!isRequired || hasValue(value)) {
            return;
          }
          return this.format(msg || defaultMessages.required, this.formatLabel(attr, model));
        },
        acceptance: function(value, attr, accept, model, computed, msg) {
          if (value === 'true' || (_.isBoolean(value) && value === true)) {
            return;
          }
          return this.format(msg || defaultMessages.acceptance, this.formatLabel(attr, model));
        },
        min: function(value, attr, minValue, model, computed, msg) {
          minValue = _.isFunction(minValue) ? minValue.call(model, value, attr, computed) : minValue;
          if (isNumber(value) && value >= minValue) {
            return;
          }
          return this.format(msg || defaultMessages.min, this.formatLabel(attr, model), minValue);
        },
        max: function(value, attr, maxValue, model, computed, msg) {
          maxValue = _.isFunction(maxValue) ? maxValue.call(model, value, attr, computed) : maxValue;
          if (isNumber(value) && value <= maxValue) {
            return;
          }
          return this.format(msg || defaultMessages.max, this.formatLabel(attr, model), maxValue);
        },
        range: function(value, attr, range, model, computed, msg) {
          range = _.isFunction(range) ? range.call(model, value, attr, computed) : range;
          if (isNumber(value) && value >= range[0] || value <= range[1]) {
            return;
          }
          return this.format(msg || defaultMessages.range, this.formatLabel(attr, model), range[0], range[1]);
        },
        length: function(value, attr, length, model, computed, msg) {
          length = _.isFunction(length) ? length.call(model, value, attr, computed) : length;
          if (_.isString(value) && value.length === length) {
            return;
          }
          return this.format(msg || defaultMessages.length, this.formatLabel(attr, model), length);
        },
        minLength: function(value, attr, minLength, model, computed, msg) {
          minLength = _.isFunction(minLength) ? minLength.call(model, value, attr, computed) : minLength;
          if (_.isString(value) && value.length >= minLength) {
            return;
          }
          return this.format(msg || defaultMessages.minLength, this.formatLabel(attr, model), minLength);
        },
        maxLength: function(value, attr, maxLength, model, computed, msg) {
          maxLength = _.isFunction(maxLength) ? maxLength.call(model, value, attr, computed) : maxLength;
          if (_.isString(value) && value.length <= maxLength) {
            return;
          }
          return this.format(msg || defaultMessages.maxLength, this.formatLabel(attr, model), maxLength);
        },
        rangeLength: function(value, attr, range, model, computed, msg) {
          range = _.isFunction(range) ? range.call(model, value, attr, computed) : range;
          if (_.isString(value) && value.length >= range[0] && value.length <= range[1]) {
            return;
          }
          return this.format(msg || defaultMessages.rangeLength, this.formatLabel(attr, model), range[0], range[1]);
        },
        oneOf: function(value, attr, values, model, computed, msg) {
          if (_.include(values, value)) {
            return;
          }
          return this.format(msg || defaultMessages.oneOf, this.formatLabel(attr, model), values.join(', '));
        },
        equalTo: function(value, attr, equalTo, model, computed, msg) {
          if (value === computed[equalTo]) {
            return;
          }
          msg || (msg = defaultMessages.equalTo);
          return this.format(msg, this.formatLabel(attr, model), this.formatLabel(equalTo, model));
        },
        notEqualTo: function(value, attr, notEqualTo, model, computed, msg) {
          if (value !== computed[notEqualTo]) {
            return;
          }
          msg || (msg = defaultMessages.notEqualTo);
          return this.format(msg, this.formatLabel(attr, model), this.formatLabel(notEqualTo, model));
        },
        validCollection: function(value, attr, valid, model, computed, msg) {
          var errorMessage, errors, isValid;
          isValid = _.isFunction(valid) ? valid.call(model, value, attr, computed) : valid;
          if (!isValid) {
            return;
          }
          errors = value.filter(function(entry) {
            return !entry.isNew();
          }).map(function(entry) {
            return entry.validate();
          });
          if (_.find(errors, function(error) {
            return !!error;
          }) == null) {
            return;
          }
          errorMessage = _.chain(errors.filter(function(error) {
            return !!error;
          })).map(function(error) {
            return _.values(error);
          }).flatten().value().join('; ');
          return this.format(msg || defaultMessages.validCollection, this.formatLabel(attr, model), errorMessage);
        },
        pattern: function(value, attr, pattern, model, computed, msg) {
          pattern = _.isFunction(pattern) ? pattern.call(model, value, attr, computed) : pattern;
          if (hasValue(value) && value.toString().match(defaultPatterns[pattern] || pattern)) {
            return;
          }
          msg || (msg = defaultMessages[pattern] || defaultMessages.inlinePattern);
          return this.format(msg, this.formatLabel(attr, model), pattern);
        }
      };
    })();
    _.each(defaultValidators, function(validator, key) {
      defaultValidators[key] = _.bind(defaultValidators[key], _.extend({}, formatFunctions, defaultValidators));
    });
    return Validation;
  })(_);

}).call(this);
