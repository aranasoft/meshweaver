pkg = require './package.json'

isTeamCity = process?.env?.TEAMCITY_VERSION?

output =
  jsDir:  'dist'

files =
  coffee:
    app: 'src/**/*.coffee'

module.exports =
  output: output
  files:  files
  coffeelint:
    reporter:       if (isTeamCity) then 'coffeelint-teamcity' else 'coffeelint-stylish'

