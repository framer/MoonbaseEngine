### Cactus with Gulp

This is a reimplementation of Cactus' ideas with [Gulp](http://gulpjs.com). No fancy app, just a command line tool. The main goal for this was speed, as larger Cactus projects became slow to work on. Other goals are portability so everyone can start building right away. Next to that, the added benefits are minified and compiled Java/Coffee Script, the posibilities to run tests, etc.

#### Features

- Built in server with automatic reloading on changes, based on [Express](http://expressjs.com) and [Live Reload](https://github.com/napcs/node-livereload)
- Template engine (like Django, with extend) based on [Nunjucks](https://mozilla.github.io/nunjucks/) – [Docs](https://mozilla.github.io/nunjucks/templating.html)
- Markdown support (with `{% markdown %}`) based on [Marked](https://github.com/chjj/marked)
- Code highlighting in Markdown, based on [Highlights](https://github.com/atom/highlights)
- Support for SCSS and includes, including minification sourcemaps.
- Support for Java/Coffee Script (with minification and sourcemaps), based on [Webpack](https://webpack.github.io)

#### Usage

- Make sure you have Node.js installed (easiest way is through [Homebrew](http://brew.sh)).
- Install moonbase in your project with `npm install --save moonbase`.
- Add the example `extras/Makefile` from extras to your project.
- Run `make` to start an auto refreshing web server.
- Change some content in the `site` folder (see layout below).
- Run `make build` to generate a site for uploading.

#### Project layout

```
config.coffee		Configuration variables like global context for templates.
gulpfile.coffee		All the logic for the different tasks like build and watch.
Makefile			Shorthands for commands to quickly build or install.
site				Main content for the generated site.
	static			Just static files like images, fonts and downloads.
	pages			The html pages including site structure.
	templates		The templates used in the html pages (for extend and include).
	css				CSS and SCSS files and dependents. The top level files get compiled.
	scripts			Java/Coffee Script files and dependents. The top level files get compiled and minified.
.build				Path for the generated site (hidden by default).
```

#### Generated site layout

So you can find this structure in `.build` after a make build command.

```
/static/img/test.jpg		from: /static/img/test.jpg			Simple copy
/index.html					from: /pages/index.html				Rendered template
/about/index.html			from: /pages/about/index.html		Rendered template
/css/style.css				from: /css/style.scss				SCSS compiled and minified
/scripts/main.coffee.js		from: /scripts/main.coffee			Coffee compiled and minified
/scripts/main.coffee.js.map	from: /scripts/main.coffee			Coffee sourcemap
/scripts/tracker.js			from: /scripts/tracker.js			JavaScript minified
```

#### Todo

- Better error reporting
- CSS Minification
- Page contexts
- Some form of deploying with rsync, s3
- Custom plugins
- Port blog plugin
- Tests
- Make sure uploaded dirs can't get touched by watch
- Maybe move /subdir/subdir.index.html to /subdir/index.html
- Maybe add some command line tool
