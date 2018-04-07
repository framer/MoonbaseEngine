var _ = require("lodash");
var autoprefixer = require("autoprefixer");
var browserSync = require("browser-sync").create();
var changed = require("gulp-changed");
var changedInPlace = require("gulp-changed-in-place");
var data = require("gulp-data");
var del = require("del");
var emptytask = require("gulp-empty");
var execSync = require("child_process").execSync;
var express = require("express");
var fs = require("fs-extra");
var gulp = require("gulp");
var gulpif = require("gulp-if");
var gulpnunjucks = require("gulp-nunjucks-html");
var gutil = require("gulp-util");
var Highlights = require("highlights");
var https = require("https");
var imagemin = require("imagemin-pngquant");
var ip = require("ip");
var join = require("path").join;
var markdown = require("nunjucks-markdown");
var marked = require("marked");
var md5 = require("gulp-md5-assets");
var merge = require("merge-stream");
var minifycss = require("gulp-minify-css");
var named = require("vinyl-named");
var nunjucksDate = require("nunjucks-date");
var plumber = require("gulp-plumber");
var portfinder = require("portfinder");
var postcss = require("gulp-postcss");
var purify = require("gulp-purifycss");
var reporter = require("postcss-reporter");
var sass = require("gulp-sass");
var sourcemaps = require("gulp-sourcemaps");
var st = require("st");
var stylelint = require("gulp-stylelint");
var watch = require("gulp-watch");
var webpack = require("webpack-stream");
var workingPath = process.cwd();

var paths = {
  build: ".build",
  templates: "templates",
  pages: "pages",
  static: "assets/static",
  scss: "assets/css",
  javascript: "assets/scripts",
  coffeescript: "assets/scripts"
};

var projectPath = function(path, fileTypes) {
  if (path == null) {
    path = "";
  }
  if (fileTypes == null) {
    fileTypes = "";
  }
  return join(workingPath, path, fileTypes);
};

var buildPath = function(path, fileTypes) {
  if (path == null) {
    path = "";
  }
  if (fileTypes == null) {
    fileTypes = "";
  }
  return join(workingPath, paths.build, path, fileTypes);
};

var isDirectory = function(path) {
  var e;
  try {
    return fs.lstatSync(path).isDirectory();
  } catch (_error) {
    e = _error;
    return false;
  }
};

var filesInDir = function(path, ext) {
  if (!fs.existsSync(path)) {
    return [];
  }
  return fs.readdirSync(path).filter(function(fileName) {
    return _.endsWith(fileName, ext);
  });
};

try {
  config = require(join(process.cwd(), "config"));
  config = config[_.first(_.keys(config))];
} catch (_error) {
  e = _error;
  config = {};
}

var highlighter = new Highlights();

marked.setOptions({
  highlight: function(code, language) {
    return highlighter.highlightSync({
      fileContents: code,
      scopeName: language
    });
  }
});

nunjucksDate.setDefaultFormat("MMMM Do YYYY, h:mm:ss a");

var nunjucks = {};

var nunjucksPipe = function() {
  return gulpnunjucks({
    searchPaths: projectPath(paths.templates),
    setUp: function(env) {
      markdown.register(env, marked);
      nunjucksDate.install(env);
      nunjucks.env = env;
      return env;
    }
  });
};

var webpackConfig = {
  module: {
    rules: [
      {
        test: /.js?$/,
        loader: "babel-loader",
        query: {
          presets: ["env"]
        }
      }
    ]
  },
  resolve: {
    extensions: [".js"],
    modules: [join(__dirname, "node_modules"), "node_modules"]
  },
  output: {
    filename: "[name].js"
  },
  cache: true,
  watch: false,
  devtool: "sourcemap",
  plugins: [new webpack.webpack.optimize.UglifyJsPlugin()]
};

var imageminOptions = {
  quality: process.env.MOONBASE_IMAGEMIN_QUALITY || "65-80",
  speed: process.env.MOONBASE_IMAGEMIN_SPEED || 4
};

var getTotalSizeForFileType = function(path, ext) {
  try {
    return execSync(
      "find '" +
        path +
        "' -type f -name '*." +
        ext +
        "' -exec du -ch {} + | grep total"
    )
      .toString()
      .replace(/^\s+|\s+$/g, "")
      .split(/\s/)[0];
  } catch (_error) {
    return "0";
  }
};

var context = {
  nunjucks: nunjucks
};

gulp.task("static", function() {
  return gulp
    .src(projectPath(paths["static"], "**/*.*"))
    .pipe(changed(buildPath(paths["static"])))
    .pipe(gulp.dest(buildPath(paths["static"])))
    .pipe(browserSync.stream());
});

gulp.task("pages", function() {
  if (typeof config.before === "function") {
    config.before(context);
  }
  return gulp
    .src(projectPath(paths.pages, "**/*"))
    .pipe(plumber())
    .pipe(changedInPlace())
    .pipe(
      data(function(file) {
        return typeof config.page === "function"
          ? config.page(
              file.path.replace(projectPath(paths.pages), ""),
              file,
              context
            )
          : void 0;
      })
    )
    .pipe(nunjucksPipe())
    .pipe(gulp.dest(buildPath()))
    .pipe(browserSync.stream());
});

gulp.task("stylelint", function() {
  var settings;
  settings = JSON.parse(fs.readFileSync("./package.json"));
  if (settings.stylelint || fs.existsSync(projectPath("", ".stylelintrc"))) {
    return gulp
      .src(projectPath(paths.scss, "**/*.scss"))
      .pipe(plumber())
      .pipe(
        stylelint({
          reporters: [
            {
              formatter: "string",
              console: true
            }
          ]
        })
      );
  }
});

gulp.task("scss", function() {
  var processors, ref;
  processors = [];
  if (((ref = config.style) != null ? ref.autoprefixer : void 0) != null) {
    processors.push(
      autoprefixer({
        browsers: [config.style.autoprefixer]
      })
    );
  }
  return gulp
    .src(projectPath(paths.scss, "*.scss"))
    .pipe(plumber())
    .pipe(sourcemaps.init())
    .pipe(sass().on("error", sass.logError))
    .pipe(postcss(processors))
    .pipe(sourcemaps.write("."))
    .pipe(gulp.dest(buildPath(paths.scss)))
    .pipe(browserSync.stream());
});

gulp.task("javascript", function() {
  if (!filesInDir(projectPath(paths.javascript), ".js").length) {
    return emptytask;
  }
  return gulp
    .src(projectPath(paths.javascript, "*.js"))
    .pipe(plumber())
    .pipe(named())
    .pipe(webpack(webpackConfig))
    .pipe(gulp.dest(buildPath(paths.javascript)))
    .pipe(browserSync.stream());
});

gulp.task("imagemin", function() {
  return gulp
    .src(projectPath(paths["static"], "**/*.png"))
    .pipe(plumber())
    .pipe(imagemin(imageminOptions()))
    .pipe(gulp.dest(projectPath(paths["static"])));
});

gulp.task("md5", ["build"], function() {
  return gulp
    .src(buildPath("", "**/*.{css, js}"))
    .pipe(md5(10, buildPath("", "**/*.html")))
    .pipe(gulp.dest(buildPath("")));
});

gulp.task("watch", ["build"], function(cb) {
  watch(
    [
      projectPath(paths.pages, "**/*.html"),
      projectPath(paths.pages, "**/*.md"),
      projectPath(paths.templates, "**/*.html"),
      projectPath(paths.templates, "**/*.md")
    ],
    function(err, events) {
      return gulp.start("pages");
    }
  );
  watch([projectPath(paths["static"], "**/*.*")], function(err, events) {
    return gulp.start("static");
  });
  watch([projectPath(paths.scss, "**/*.scss")], function(err, events) {
    return gulp.start("scss");
  });
  watch([projectPath(paths.javascript, "**/*.js")], function(err, events) {
    return gulp.start("javascript");
  });
  return gulp.start("server", cb);
});

gulp.task("server", function(cb) {
  return portfinder.getPort(function(err, serverPort) {
    var app, sslCert, sslKey;
    portfinder.basePort = 10000;
    sslKey = __dirname + "/ssl/key.pem";
    sslCert = __dirname + "/ssl/cert.pem";
    app = express();
    app.use(express["static"](buildPath()));
    https
      .createServer(
        {
          key: fs.readFileSync(sslKey),
          cert: fs.readFileSync(sslCert)
        },
        app
      )
      .listen(serverPort);
    browserSync.init({
      proxy: "https://localhost:" + serverPort
    });
    return cb(err);
  });
});

gulp.task("report", function() {
  var commonResetClasses, ext, i, len, path, ref;
  gutil.log(gutil.colors.cyan("Total file sizes:"));
  ref = ["html", "css", "jpg", "png", "mp4"];
  for (i = 0, len = ref.length; i < len; i++) {
    ext = ref[i];
    path = getTotalSizeForFileType(buildPath(paths.assets), ext);
    gutil.log(gutil.colors.green(ext + " " + path));
  }
  commonResetClasses = [
    "applet",
    "blockquote",
    "abbr",
    "acronym",
    "cite",
    "del",
    "dfn",
    "kbd",
    "samp",
    "strike",
    "sup",
    "tt",
    "dt",
    "fieldset",
    "legend",
    "caption",
    "tfoot",
    "thead",
    "th",
    "figcaption",
    "hgroup",
    "mark",
    "blockquote",
    "blockquote:after",
    "blockquote:before",
    "textarea:focus",
    "ins"
  ];
  gutil.log("-----------------------------------------");
  gutil.log(gutil.colors.cyan("Unused CSS:"));
  return gulp.src(buildPath(paths.scss, "style.css")).pipe(
    purify([buildPath("", "**/*.html"), buildPath("", "**/*.js")], {
      rejected: true,
      whitelist: commonResetClasses
    })
  );
});

gulp.task("clean", function() {
  return del([buildPath(), "*.scss"]);
});

gulp.task("build", ["pages", "static", "scss", "javascript"]);

gulp.task("default", ["server"]);
