local plugin = {}

local misc = require('crappy.misc')
local pluginManager = require("crappy.pluginManager")

plugin.name = 'Familar Alt-Tab Functions'
plugin.description = 'Integrate familiar Alt-Tab functionality in Awesome WM'
plugin.id = 'alttab.functions'
plugin.requires = {}
plugin.provides = {"crappy.functions.global"}
plugin.functions = {
   ["alttab"] = {
      class = "global",
      description = "Integrate familiar Alt-Tab functionality in Awesome WM",
   },
}

function plugin.startup(awesomever, settings)
   alttab = require('alttab')
   plugin.functions["alttab"].func = alttab
end

function plugin.buildUi(window, settings, log)
   return nil
end

return plugin
