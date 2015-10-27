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
watch = require "gulp-watch"
webpack = require "webpack-stream"
plumber = require "gulp-plumber"
merge = require "merge-stream"
gulpif = require "gulp-if"
minifycss = require "gulp-minify-css"
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
Highlights = require "highlights"

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

isDirectory = (path) -> fs.lstatSync(path).isDirectory()
filesInDir = (path, ext) -> fs.readdirSync(path).filter (fileName) ->
	_.endsWith(fileName, ext)

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
	new webpack.webpack.optimize.UglifyJsPlugin()
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
		.pipe(sass().on("error", sass.logError))
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

	return emptytask unless isDirectory(projectPath(paths.sprites))

	spriteImagesPath = projectPath(paths.sprites, "export/*.png")
	spriteData = gulp.src(spriteImagesPath)
		.pipe(spritesmith({
			cssName: "sprite.scss"
			imgName: "sprite.png"
			retinaImgName: "sprite@2x.png"
			imgPath: "../sprites/sprite.png"
			retinaImgPath: "../sprites/sprite@2x.png"
			retinaSrcFilter: [projectPath(paths.sprites, "export/*@2x.png")]
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
