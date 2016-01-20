<a name="0.3.1"></a>
## 0.3.1 (2016-01-20)


### Bug Fixes

* **patterns:** Fix support for numeric values within string inputs ([6e187ff](https://github.com/aranasoft/meshweaver/commit/6e187ff))

### Features

* **events:** fire change event when updating model ([485d0e1](https://github.com/aranasoft/meshweaver/commit/485d0e1))


<a name="0.3.0"></a>
# 0.3.0 (2016-01-20)


### Bug Fixes

* **patterns:** Fix support for numeric values within string inputs ([6e187ff](https://github.com/aranasoft/meshweaver/commit/6e187ff))

### Features

* **collections:** Add validator to support nested backbone collections ([5cb026a](https://github.com/aranasoft/meshweaver/commit/5cb026a))
* **error:** Add support for alternative error ui elements ([e8cdd39](https://github.com/aranasoft/meshweaver/commit/e8cdd39))
* **labels:** Override `label` formatter to support property as fn ([a22e406](https://github.com/aranasoft/meshweaver/commit/a22e406))
* **notEqualTo:** add `notEqualTo` validator ([b9f4ce1](https://github.com/aranasoft/meshweaver/commit/b9f4ce1))
* **radio:** Add support for radio lists when setting model from inputs ([bbff546](https://github.com/aranasoft/meshweaver/commit/bbff546))
* **validators:** Add func-supporting overrides of Backbone.Validators ([9a05909](https://github.com/aranasoft/meshweaver/commit/9a05909))
* **view:** convert to ValidatedView ([4908a91](https://github.com/aranasoft/meshweaver/commit/4908a91))


### BREAKING CHANGE

* Marionette View must now extend from
`Meshweaver.ValidatedView`, instead of just from `Meshweaver`. Also,
any custom Validators or Validation Messages should be applied to
`Meshweaver.Validation` instead of `Backbone.Validation`.


