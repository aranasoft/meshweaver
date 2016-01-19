gulp = require 'gulp'
gutil = require 'gulp-util'
config = require './gulpconfig.coffee'
plugins = require('gulp-load-plugins')()
pkg = require './package.json'
fs = require 'fs'


gulp.task 'default', ['lint','build']

gulp.task 'build', [
  'install'
  'js'
]

hasRunInstall = false
gulp.task 'install', () ->
  return if hasRunInstall
  hasRunInstall = true
  return plugins.bower()

gulp.task 'js', ['install'], () ->
  gulp.src(config.files.coffee.app)
  .pipe(errorHandler())
  .pipe(plugins.coffee())
  .pipe(plugins.concat('meshweaver.js'))
  .pipe(plugins.header( fs.readFileSync('./src/meshweaver.prefix', 'utf8'), { pkg: pkg }))
  .pipe(gulp.dest(config.output.jsDir))
  .pipe(plugins.rename
    suffix: ".min"
    extname: ".js"
  ).pipe(plugins.sourcemaps.init({loadMaps: true}))
  .pipe(plugins.uglify())
  .pipe(plugins.sourcemaps.write('./'))
  .pipe(gulp.dest(config.output.jsDir))

gulp.task 'lint', ['install'], () ->
  gulp.src(config.files.coffee.app)
    .pipe(errorHandler())
    .pipe(plugins.coffeelint())
    .pipe(plugins.coffeelint.reporter(config.coffeelint.reporter))

gulp.task 'watch', ['default'], (done) ->
  gulp.watch config.files.coffee.app, {debounceDelay: 2000}, ['lint','js']

  done()


# Utilities
onError = (err) ->
  gutil.log(gutil.colors.red err)
  @emit 'end'

errorHandler = () ->
  plugins.plumber {errorHandler: onError}
