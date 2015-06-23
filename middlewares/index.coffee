# attempts to recursively import and register any sub-middlewares in the current module
#
# TL;DR; use this as index.coffee in all middleware subfolders
path = require "path"
fs = require "fs"


module.exports = (app) ->
    load = (file) ->
        # load and register submodule
        submodule = require("./" + file)
        submodule(app)

        # export any registered properties
        for own prop of submodule
            module.exports[prop] = submodule[prop]

    for file in fs.readdirSync(__dirname)
        stat = fs.statSync(path.join(__dirname, file))
        if stat.isDirectory()
            # subfolder; assume submodule
            load(file)
        else
            # subfile; only load coffee and js files to avoid .gitkeep, coffeelint.json, etc.
            [file, extension] = file.split(".", 2)
            if file isnt "index" and extension in ["coffee", "js"]
                load(file)
