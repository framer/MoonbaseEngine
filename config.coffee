gulp = require "gulp"
gutil = require "gulp-util"

memoizee = require "memoizee"
nunjucks = require "gulp-nunjucks-html"
livereload = require "gulp-livereload"
sass = require "gulp-sass"
changed = require "gulp-changed"

lr = require "connect-livereload"
st = require "st"
portfinder = require "portfinder"
express = require "express"
marked = require "marked"
highlightjs = require "highlight.js"

paths =
	build: "#{__dirname}/.build"
	templates: ["#{__dirname}/templates"],
	pages: ["pages/**/*.html"],
	static: "static/**/*.*"
	scss: ["static/css/*.scss"],
	scripts: [],
	
marked.setOptions
	highlight: (code, lang) ->
		{value, language} = highlightjs.highlightAuto(code, ["coffeescript"])
		return value

markdown = memoizee(marked)
# markdown = marked

setupNunjucks = (env) ->

	env.addFilter "markdown", (body) ->
		env.renderString(markdown(body))

	return env

# gulp.task "clean", ->
#   return del([paths.build])

gulp.task("build", ["pages", "static", "scss"])

gulp.task "static", ->
	gulp.src(paths.static)
		.pipe(changed("#{paths.build}/static"))
		.pipe(gulp.dest("#{paths.build}/static"))
		.pipe(livereload())

gulp.task "pages", ->
	gulp.src(paths.pages)
        .pipe(nunjucks({searchPaths:paths.templates, setUp:setupNunjucks}))
        .pipe(gulp.dest(paths.build))
        .pipe(livereload())

gulp.task "scss", ->
	gulp.src(paths.scss)
		.pipe(sass().on("error", sass.logError))
		.pipe(gulp.dest("#{paths.build}/static/css"))
		.pipe(livereload())

gulp.task "watch", ["build"], ->
	gulp.watch([paths.static, "!static/css/**/*.scss"], ["static"])
	gulp.watch(["static/css/**/*.scss"], ["scss"])
	gulp.watch(["pages/**/*.html", "templates/**/*.html"], ["pages"])

gulp.task "server", ["watch"], (cb) ->

	app = express()
	app.use(lr())
	app.use(express.static(paths.build))

	portfinder.getPort (err, port)  ->

		app.listen(port)
		livereload.listen basePath:paths.build
		gutil.log(gutil.colors.green("Serving at: http://localhost:#{port}"))
		cb(err)


gulp.task("default", ["server"])
