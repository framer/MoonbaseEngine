_ = require "lodash"
{join} = require "path"
fs = require "fs-extra"
{execSync} = require "child_process"
https = require "https"

ip = require "ip"
gulp = require "gulp"
gutil = require "gulp-util"

gulpnunjucks = require "gulp-nunjucks-html"
nunjucksDate = require "nunjucks-date"
browserSync = require("browser-sync").create();
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
imagemin = require "imagemin-pngquant"
md5 = require "gulp-md5-assets"
postcss = require "gulp-postcss"
reporter = require "postcss-reporter"
autoprefixer = require "autoprefixer"
stylelint = require "gulp-stylelint"
purify = require "gulp-purifycss"

st = require "st"
portfinder = require "portfinder"
express = require "express"

markdown = require "nunjucks-markdown"
marked = require "marked"
Highlights = require "highlights"
imagemin = require "imagemin-pngquant"
named = require "vinyl-named"


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

projectPath = 	(path="", fileTypes="") -> join(workingPath, path, fileTypes)
buildPath = 	(path="", fileTypes="") -> join(workingPath, paths.build, path, fileTypes)

isDirectory = (path) ->
	try
		return fs.lstatSync(path).isDirectory()
	catch e
		return false

filesInDir = (path, ext) ->
	return [] unless fs.existsSync(path)
	fs.readdirSync(path).filter (fileName) ->
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

nunjucksDate.setDefaultFormat("MMMM Do YYYY, h:mm:ss a")

nunjucks = {}
nunjucksPipe = -> gulpnunjucks
	searchPaths: projectPath(paths.templates)
	setUp: (env) ->
		markdown.register(env, marked)
		nunjucksDate.install(env)
		nunjucks.env = env
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
	quiet: true
	watch: false
	devtool: "sourcemap"

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

# Imagemin

imageminOptions =
	quality: process.env.MOONBASE_IMAGEMIN_QUALITY or "65-80"
	speed: process.env.MOONBASE_IMAGEMIN_SPEED or 4

# Utilities

getTotalSizeForFileType = (path, ext) ->
	try
		return execSync("find '#{path}' -type f -name '*.#{ext}' -exec du -ch {} + | grep total")
			.toString().replace(/^\s+|\s+$/g, "").split(/\s/)[0]
	catch
		return "0"

# Context

context =
	nunjucks: nunjucks

# Gulp Tasks

gulp.task "static", ->
	gulp.src(projectPath(paths.static, "**/*.*"))
		.pipe(changed(buildPath(paths.static)))
		.pipe(gulp.dest(buildPath(paths.static)))
		.pipe(browserSync.stream())

gulp.task "pages", ->
	config.before?(context)
	gulp.src(projectPath(paths.pages, "**/*"))
		.pipe(plumber())
		.pipe(data((file) -> config.page?(file.path.replace(projectPath(paths.pages), ""), file, context)))
		.pipe(nunjucksPipe())
		.pipe(gulp.dest(buildPath()))
		.pipe(browserSync.stream())

gulp.task "stylelint", ->

	# Check if there's a stylelint configuration
	settings = JSON.parse(fs.readFileSync('./package.json'))
	if settings.stylelint or fs.existsSync(projectPath("", ".stylelintrc"))
		gulp.src(projectPath(paths.scss, "**/*.scss"))
			.pipe(plumber())
			.pipe(stylelint({
				reporters: [
					{formatter: 'string', console: true}
				]
		}))

gulp.task "scss", ->
	processors = []

	if config.style?.autoprefixer?
		processors.push(autoprefixer({ browsers: [config.style.autoprefixer] }))

	gulp.src(projectPath(paths.scss, "*.scss"))
		.pipe(plumber())
		.pipe(sourcemaps.init())
		.pipe(sass().on("error", sass.logError))
		.pipe(postcss(processors))
		.pipe(sourcemaps.write("."))
		.pipe(gulp.dest(buildPath(paths.scss)))
		.pipe(browserSync.stream())

gulp.task "coffeescript", ->

	return emptytask unless filesInDir(
		projectPath(paths.coffeescript), ".coffee").length

	gulp.src(projectPath(paths.coffeescript, "*.coffee"))
		.pipe(plumber())
		.pipe(named())
		.pipe(webpack(webpackConfigCoffeeScript))
		.pipe(gulp.dest(buildPath(paths.coffeescript)))
		.pipe(browserSync.stream())

gulp.task "javascript", ->

	return emptytask unless filesInDir(
		projectPath(paths.javascript), ".js").length

	gulp.src(projectPath(paths.javascript, "*.js"))
		.pipe(plumber())
		.pipe(named())
		.pipe(webpack(webpackConfigJavaScript))
		.pipe(gulp.dest(buildPath(paths.javascript)))
		.pipe(browserSync.stream())

gulp.task "imagemin", ->
	return gulp.src(projectPath(paths.static, "**/*.png"))
		.pipe(plumber())
		.pipe(imagemin(imageminOptions)())
		.pipe(gulp.dest(projectPath(paths.static)))

gulp.task "md5", ["build"], ->
	return gulp.src(buildPath("", "**/*.{css, js}"))
		.pipe(md5(10, buildPath("", "**/*.html")))
		.pipe(gulp.dest(buildPath("")))

gulp.task "watch", ["build"], (cb) ->

	# Wait 100ms before we actually reload
	options = {debounceDelay: 100}

	watch [
		projectPath(paths.pages, "**/*.html"),
		projectPath(paths.pages, "**/*.md"),
		projectPath(paths.templates, "**/*.html"),
		projectPath(paths.templates, "**/*.md")
	], options, (err, events) -> gulp.start("pages")

	watch [projectPath(paths.static, "**/*.*")], options, (err, events) ->
		gulp.start("static")
	watch [projectPath(paths.scss, "**/*.scss")], options, (err, events) ->
		gulp.start("scss")
	watch [projectPath(paths.coffeescript, "**/*.coffee")], options, (err, events) ->
		gulp.start("coffeescript")
	watch [projectPath(paths.javascript, "**/*.js")], options, (err, events) ->
		gulp.start("javascript")

	gulp.start("server", cb)

gulp.task "server", (cb) ->

	portfinder.getPort (err, serverPort)  ->
		portfinder.basePort = 10000

		sslKey = "#{__dirname}/ssl/key.pem"
		sslCert = "#{__dirname}/ssl/cert.pem"

		app = express()
		app.use(express.static(buildPath()))
		https.createServer({
			key: fs.readFileSync(sslKey),
			cert: fs.readFileSync(sslCert)
		}, app).listen(serverPort)

		browserSync.init({
			proxy: "https://localhost:#{serverPort}",
			# https: {
			# 	key: fs.readFileSync(sslKey),
			# 	cert: fs.readFileSync(sslCert)
			# }
		})

		cb(err)

gulp.task "report", ->

	# Report on sizes for each file type
	gutil.log(gutil.colors.cyan("Total file sizes:"))
	for ext in ["html", "css", "jpg", "png", "mp4"]
		path = getTotalSizeForFileType(buildPath(paths.assets), ext)
		gutil.log(gutil.colors.green("#{ext} #{path}"))

	# Check all html and js files to see if there's any unused CSS
	commonResetClasses = [
		"applet", "blockquote", "abbr", "acronym", "cite", "del", "dfn", "kbd", "samp", "strike", "sup", "tt", "dt", "fieldset", "legend", "caption", "tfoot", "thead", "th", "figcaption", "hgroup", "mark", "blockquote", "blockquote:after", "blockquote:before", "textarea:focus", "ins"
	]
	
	gutil.log("-----------------------------------------")
	gutil.log(gutil.colors.cyan("Unused CSS:"))
	return gulp.src(buildPath(paths.scss, "style.css"))
		.pipe(purify(
			[buildPath("", "**/*.html"), buildPath("", "**/*.js")],
			{rejected: true, whitelist: commonResetClasses}
		))

gulp.task "clean", ->
	return del([buildPath(), "*.scss"])

gulp.task("build", ["pages", "static", "scss", "coffeescript", "javascript"])
gulp.task("default", ["server"])
