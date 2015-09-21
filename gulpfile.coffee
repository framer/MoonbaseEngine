_ = require "lodash"
{join} = require "path"

gulp = require "gulp"
gutil = require "gulp-util"

memoizee = require "memoizee"
nunjucks = require "gulp-nunjucks-html"
livereload = require "gulp-livereload"
sass = require "gulp-sass"
changed = require "gulp-changed"
watch = require "gulp-watch"
webpack = require "webpack-stream"
plumber = require "gulp-plumber"

lr = require "connect-livereload"
st = require "st"
portfinder = require "portfinder"
express = require "express"

markdown = require "nunjucks-markdown"
marked = require "marked"
Highlights = require "highlights"


# Path configurations

# We are assuming we're in node_modules for now
workingPath = process.cwd()

paths =
	build: 			".build"
	templates: 		"templates"
	pages: 			"pages"
	static: 		"assets/static"
	scss: 			"assets/css"
	javascript: 	"assets/scripts"
	coffeescript: 	"assets/scripts"

projectPath = 	(path="", fileTypes="") -> join(workingPath, path, fileTypes)
buildPath = 	(path="", fileTypes="") -> join(workingPath, paths.build, path, fileTypes)


# Template engine

highlighter = new Highlights()

marked.setOptions
	highlight: (code, language) ->
		return highlighter.highlightSync
			fileContents: code
			scopeName: language

setupNunjucks = (env) ->
	markdown.register(env, marked)
	return env


# Webpack

webpackConfig = 
	module: loaders: [{ test: /\.coffee$/, loader: "coffee" }]
	resolve: extensions: ["", ".coffee", ".js"]
	output:
		filename: "[name].js"
	cache: true
	devtool: "sourcemap"

webpackConfigPlugins = [
	new webpack.webpack.optimize.DedupePlugin(),
	new webpack.webpack.optimize.UglifyJsPlugin
		mangle: false
		compress:
			warnings: true
]

webpackConfigJavaScript = _.cloneDeep(webpackConfig)
webpackConfigJavaScript.output.filename = "[name].js"
webpackConfigJavaScript.plugins = webpackConfigPlugins
webpackConfigCoffeeScript = _.cloneDeep(webpackConfig)
webpackConfigCoffeeScript.output.filename = "[name].coffee.js"
webpackConfigCoffeeScript.plugins = webpackConfigPlugins

# Gulp Tasks

gulp.task "static", ->
	gulp.src(projectPath(paths.static, "**/*.*"))
		.pipe(changed(buildPath(paths.static, "**/*.*")))
		.pipe(gulp.dest(buildPath(paths.static)))
		.pipe(livereload())

gulp.task "pages", ->
	gulp.src(projectPath(paths.pages, "**/*"))
		.pipe(plumber())
		.pipe(nunjucks(
			searchPaths: projectPath(paths.templates)
			setUp: setupNunjucks))
		.pipe(gulp.dest(buildPath()))
		.pipe(livereload())

gulp.task "scss", ->
	gulp.src(projectPath(paths.scss, "*.scss"))
		.pipe(sass().on("error", sass.logError))
		.pipe(gulp.dest(buildPath(paths.scss)))
		.pipe(livereload())

gulp.task "coffeescript", ->
	gulp.src(projectPath(paths.coffeescript, "*.coffee"))
		.pipe(webpack(webpackConfigCoffeeScript))
		.pipe(gulp.dest(buildPath(paths.coffeescript)))
		.pipe(livereload())

gulp.task "javascript", ->
	gulp.src(projectPath(paths.javascript, "*.js"))
		.pipe(webpack(webpackConfigJavaScript))
		.pipe(gulp.dest(buildPath(paths.javascript)))
		.pipe(livereload())

gulp.task "watch", ["build"], (cb) ->

	watch [
		projectPath(paths.pages, "**/*.html"),
		projectPath(paths.pages, "**/*.md"),
		projectPath(paths.templates, "**/*.html"),
		projectPath(paths.templates, "**/*.md")
	], (err, events) -> gulp.start("pages")

	watch [projectPath(paths.static, "**/*.*")], (err, events) -> gulp.start("static")
	watch [projectPath(paths.scss, "**/*.scss")], (err, events) -> gulp.start("scss")
	watch [projectPath(paths.coffeescript, "**/*.coffee")], (err, events) -> gulp.start("coffeescript")
	watch [projectPath(paths.javascript, "**/*.js")], (err, events) -> gulp.start("javascript")

	gulp.start("server", cb)

gulp.task "server", (cb) ->

	app = express()
	app.use(lr())
	app.use(express.static(buildPath()))

	portfinder.getPort (err, port)  ->
		app.listen(port)
		livereload.listen(basePath:buildPath())
		gutil.log(gutil.colors.green("Serving at: http://localhost:#{port}"))
		gutil.log(gutil.colors.green("From path:  #{buildPath()}"))
		cb(err)

gulp.task("build", ["pages", "static", "scss", "coffeescript", "javascript"])
gulp.task("default", ["server"])
