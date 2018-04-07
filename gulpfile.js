var Highlights,
  _,
  autoprefixer,
  browserSync,
  buildPath,
  changed,
  changedInPlace,
  config,
  context,
  data,
  del,
  e,
  emptytask,
  execSync,
  express,
  filesInDir,
  fs,
  getTotalSizeForFileType,
  gulp,
  gulpif,
  gulpnunjucks,
  gutil,
  highlighter,
  https,
  imagemin,
  imageminOptions,
  ip,
  isDirectory,
  join,
  markdown,
  marked,
  md5,
  merge,
  minifycss,
  named,
  nunjucks,
  nunjucksDate,
  nunjucksPipe,
  paths,
  plumber,
  portfinder,
  postcss,
  projectPath,
  purify,
  reporter,
  sass,
  sourcemaps,
  st,
  stylelint,
  watch,
  webpack,
  webpackConfig,
  workingPath;

_ = require("lodash");
autoprefixer = require("autoprefixer");
browserSync = require("browser-sync").create();
changed = require("gulp-changed");
changedInPlace = require("gulp-changed-in-place");
data = require("gulp-data");
del = require("del");
emptytask = require("gulp-empty");
execSync = require("child_process").execSync;
express = require("express");
fs = require("fs-extra");
gulp = require("gulp");
gulpif = require("gulp-if");
gulpnunjucks = require("gulp-nunjucks-html");
gutil = require("gulp-util");
Highlights = require("highlights");
https = require("https");
imagemin = require("imagemin-pngquant");
ip = require("ip");
join = require("path").join;
markdown = require("nunjucks-markdown");
marked = require("marked");
md5 = require("gulp-md5-assets");
merge = require("merge-stream");
minifycss = require("gulp-minify-css");
named = require("vinyl-named");
nunjucksDate = require("nunjucks-date");
plumber = require("gulp-plumber");
portfinder = require("portfinder");
postcss = require("gulp-postcss");
purify = require("gulp-purifycss");
reporter = require("postcss-reporter");
sass = require("gulp-sass");
sourcemaps = require("gulp-sourcemaps");
st = require("st");
stylelint = require("gulp-stylelint");
watch = require("gulp-watch");
webpack = require("webpack-stream");

workingPath = process.cwd();

paths = {
  build: ".build",
  templates: "templates",
  pages: "pages",
  static: "assets/static",
  scss: "assets/css",
  javascript: "assets/scripts",
  coffeescript: "assets/scripts"
};

projectPath = function(path, fileTypes) {
  if (path == null) {
    path = "";
  }
  if (fileTypes == null) {
    fileTypes = "";
  }
  return join(workingPath, path, fileTypes);
};

buildPath = function(path, fileTypes) {
  if (path == null) {
    path = "";
  }
  if (fileTypes == null) {
    fileTypes = "";
  }
  return join(workingPath, paths.build, path, fileTypes);
};

isDirectory = function(path) {
  var e;
  try {
    return fs.lstatSync(path).isDirectory();
  } catch (_error) {
    e = _error;
    return false;
  }
};

filesInDir = function(path, ext) {
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

highlighter = new Highlights();

marked.setOptions({
  highlight: function(code, language) {
    return highlighter.highlightSync({
      fileContents: code,
      scopeName: language
    });
  }
});

nunjucksDate.setDefaultFormat("MMMM Do YYYY, h:mm:ss a");

nunjucks = {};

nunjucksPipe = function() {
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

webpackConfig = {
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

imageminOptions = {
  quality: process.env.MOONBASE_IMAGEMIN_QUALITY || "65-80",
  speed: process.env.MOONBASE_IMAGEMIN_SPEED || 4
};

getTotalSizeForFileType = function(path, ext) {
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

context = {
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
