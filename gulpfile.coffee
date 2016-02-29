_ = require "lodash"
{join, basename, extname} = require "path"
fs = require "fs-extra"
glob = require "glob"

gulp = require "gulp"
gutil = require "gulp-util"

gulpnunjucks = require "gulp-nunjucks-html"
livereload = require "gulp-livereload"
sass = require "gulp-sass"
changed = require "gulp-changed"
newer = require "gulp-newer"
watch = require "gulp-watch"
webpack = require "webpack-stream"
plumber = require "gulp-plumber"
merge = require "merge-stream"
gulpif = require "gulp-if"
# minifycss = require "gulp-minify-css"
sourcemaps = require "gulp-sourcemaps"
emptytask = require "gulp-empty"
data = require "gulp-data"
newy = require "./vendor/newy"
del = require "del"
spritesmith = require "gulp.spritesmith"

lr = require "connect-livereload"
st = require "st"
portfinder = require "portfinder"
express = require "express"

markdown = require "nunjucks-markdown"
marked = require "marked"
moment = require "moment"
Highlights = require "highlights"
moduleImporter = require "sass-module-importer"


# Path configurations

workingPath = process.cwd()
# workingSession = Math.floor(Date.now() / 1000)

paths =
	build: 			".build"
	templates: 		"templates"
	pages: 			"pages"
	static: 		"assets/static"
	scss: 			"assets/css"
	javascript: 	"assets/scripts"
	coffeescript: 	"assets/scripts"
	sprites:		"assets/sprites"

projectPath = 	(path="", fileTypes="") -> join(workingPath, path, fileTypes)
buildPath = 	(path="", fileTypes="") -> join(workingPath, paths.build, path, fileTypes)

isDirectory = (path) ->
	return false unless fs.existsSync(path)
	return fs.lstatSync(path).isDirectory()
filesInDir = (path, ext) ->
	return [] unless fs.existsSync(path)
	return fs.readdirSync(path).filter (fileName) -> _.endsWith(fileName, ext)

# Exports

exports.nunjucks =
	env: null


# Configuration

try
	config = require(join(process.cwd(), "config"))
	config = config[_.first(_.keys(config))]
catch e
	config = {}

# Template engine

highlighter = new Highlights()

marked.setOptions
	highlight: (code, language) ->
		return highlighter.highlightSync
			fileContents: code
			scopeName: language

nunjucks = ->
	gulpnunjucks
		searchPaths: projectPath(paths.templates)
		setUp: (env) ->
			markdown.register(env, marked)

			env.addFilter "date", (date, format) ->
				return moment(date).format(format)

			exports.nunjucks.env = env

			return env

# Webpack

webpackConfig =
	module:
		loaders: [{test: /\.coffee$/, loader: "coffee-loader"}]
	resolve: extensions: ["", ".coffee", ".js"]
	resolveLoader: {root: join(__dirname, "node_modules")}
	output:
		filename: "[name].js"
	cache: true
	devtool: "sourcemap"
	watch: false

webpackConfigPlugins = [
	new webpack.webpack.optimize.DedupePlugin(),
	new webpack.webpack.optimize.UglifyJsPlugin(compress: warnings: false)
]

webpackConfigJavaScript = _.cloneDeep(webpackConfig)
webpackConfigJavaScript.output.filename = "[name].js"
webpackConfigJavaScript.plugins = webpackConfigPlugins
webpackConfigCoffeeScript = _.cloneDeep(webpackConfig)
webpackConfigCoffeeScript.output.filename = "[name].coffee.js"
webpackConfigCoffeeScript.plugins = webpackConfigPlugins

webpackEntries = (path) ->
	entry = {}

	for p in glob.sync(path)
		entry[basename(p, extname(p))] = p

	return entry

# Gulp Tasks

gulp.task "static", ->
	gulp.src(projectPath(paths.static, "**/*.*"))
		.pipe(changed(buildPath(paths.static)))
		.pipe(gulp.dest(buildPath(paths.static)))
		.pipe(livereload())

gulp.task "pages", ->
	config.before?()
	gulp.src(projectPath(paths.pages, "**/*"))
		.pipe(plumber())
		.pipe(data((file) -> config.page(file.path.replace(projectPath(paths.pages), ""), file)))
		.pipe(nunjucks())
		.pipe(gulp.dest(buildPath()))
		.pipe(livereload())

gulp.task "scss", ["sprites"], ->
	gulp.src(projectPath(paths.scss, "*.scss"))
		#.pipe(sourcemaps.init())
		.pipe(sass(importer: moduleImporter()).on("error", sass.logError))
		#.pipe(minifycss(rebase: false))
		#.pipe(sourcemaps.write("."))
		.pipe(gulp.dest(buildPath(paths.scss)))
		.pipe(livereload())

gulp.task "coffeescript", ->

	return emptytask unless filesInDir(
		projectPath(paths.coffeescript), ".coffee").length

	webpackConfigCoffeeScript.entry = webpackEntries(
		projectPath(paths.coffeescript, "*.coffee"))

	gulp.src(projectPath(paths.coffeescript, "*.coffee"))
		.pipe(webpack(webpackConfigCoffeeScript))
		.pipe(gulp.dest(buildPath(paths.coffeescript)))
		.pipe(livereload())

gulp.task "javascript", ->

	return emptytask unless filesInDir(
		projectPath(paths.javascript), ".js").length

	webpackConfigJavaScript.entry = webpackEntries(
		projectPath(paths.javascript, "*.js"))

	gulp.src(projectPath(paths.javascript, "*.js"))
		.pipe(webpack(webpackConfigJavaScript))
		.pipe(gulp.dest(buildPath(paths.javascript)))
		.pipe(livereload())

gulp.task "sprites", ->

	# Build a sprite package from every folder in assets/sprites

	# Return if there is no sprite assets folder at all
	return emptytask unless isDirectory(projectPath(paths.sprites))

	# Look for sprite package folders in the sprite assets folder
	sprites = fs.readdirSync(projectPath(paths.sprites)).filter (fileName) ->
		isDirectory(join(projectPath(paths.sprites), fileName))

	return emptytask unless sprites.length > 0

	# Build a sprite package from every folder and output scss and images
	return merge sprites.map (fileName) ->

		gutil.log("Building sprites for \"#{fileName}\"")

		spriteImagesPath = projectPath(paths.sprites, "#{fileName}/*.png")
		spriteData = gulp.src(spriteImagesPath)
			.pipe(newer(buildPath(paths.sprites, "#{fileName}/*.png")))
			.pipe(spritesmith({
				cssName: "#{fileName}.scss"
				imgName: "#{fileName}.png"
				retinaImgName: "#{fileName}@2x.png"
				# These paths need to be relative to the server
				imgPath: "../sprites/#{fileName}.png"
				retinaImgPath: "../sprites/#{fileName}@2x.png"
				retinaSrcFilter: [projectPath(paths.sprites, "#{fileName}/*@2x.png")]
			}
		))

		imgStream = spriteData.img
			# .pipe(imagemin())
			.pipe(gulp.dest(buildPath(paths.sprites)));

		cssStream = spriteData.css
			# .pipe(csso())
			.pipe(gulp.dest(projectPath(paths.sprites)));

		return merge(imgStream, cssStream).pipe(livereload())

gulp.task "watch", ["build"], (cb) ->

	watch [
		projectPath(paths.pages, "**/*.html"),
		projectPath(paths.pages, "**/*.md"),
		projectPath(paths.templates, "**/*.html"),
		projectPath(paths.templates, "**/*.md")
	], (err, events) -> gulp.start("pages")

	watch [projectPath(paths.static, "**/*.*")], (err, events) ->
		gulp.start("static")
	watch [projectPath(paths.scss, "**/*.scss")], (err, events) ->
		gulp.start("scss")
	watch [projectPath(paths.coffeescript, "**/*.coffee")], (err, events) ->
		gulp.start("coffeescript")
	watch [projectPath(paths.javascript, "**/*.js")], (err, events) ->
		gulp.start("javascript")
	watch [projectPath(paths.sprites, "*/*.png")], (err, events) ->
		gulp.start("scss")

	gulp.start("server", cb)

gulp.task "server", (cb) ->

	portfinder.basePort = 9000
	portfinder.getPort (err, serverPort)  ->
		portfinder.basePort = 10000
		portfinder.getPort (err, livereloadPort)  ->

			app = express()
			app.use(lr(port:livereloadPort))
			app.use(express.static(buildPath()))
			app.listen(serverPort)

			livereload.listen(port:livereloadPort, basePath:buildPath())

			gutil.log(gutil.colors.green("Serving at: http://localhost:#{serverPort}"))
			gutil.log(gutil.colors.green("From path:  #{buildPath()}"))

			cb(err)

gulp.task "clean", ->
	return del([buildPath(), projectPath(paths.sprites, "*.scss")])

gulp.task("build", ["pages", "static", "scss", "coffeescript", "javascript"])
gulp.task("default", ["server"])
