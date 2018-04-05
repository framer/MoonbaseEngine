#!/usr/bin/env node
var args,
  fs,
  gulp,
  gulpfile,
  gutil,
  isValidMoonbasePath,
  join,
  normalize,
  path,
  prettyTime,
  program,
  resolve,
  task;

({ normalize, resolve, join } = require("path"));

fs = require("fs");

({ join } = require("path"));

gulp = require("gulp");

gutil = require("gulp-util");

prettyTime = require("pretty-hrtime");

program = require("commander");

isValidMoonbasePath = function(path) {
  var folder, i, len, ref;
  ref = ["pages", "templates", "assets"];
  for (i = 0, len = ref.length; i < len; i++) {
    folder = ref[i];
    if (!fs.existsSync(join(path, folder))) {
      return false;
    }
    if (!fs.lstatSync(join(path, folder)).isDirectory()) {
      return false;
    }
  }
  return true;
};

task = "watch";

path = process.cwd();

args = [];

program
  .version("0.0.1")
  .arguments("moonbase [path] [task] [args...]")
  .action(function(cmdtask, cmdpath, args) {
    task = cmdtask || task;
    path = cmdpath || path;
    return (args = args);
  });

program.parse(process.argv);

path = resolve(normalize(path));

console.log(fs.readFileSync(join(__dirname, "banner.txt"), "utf8"));

gutil.log(`Running ${task} for ${path}`);

if (!isValidMoonbasePath(path)) {
  gutil.log(gutil.colors.red("Error: this is not a moonbase project path:"));
  gutil.log(gutil.colors.red(path));
  process.exit(1);
}

process.chdir(path);

gulpfile = require("./gulpfile");

gulp.on("task_stop", function(e) {
  return gutil.log(
    `${e.task} ${gutil.colors.grey("in")} ${prettyTime(e.hrDuration)}`
  );
});

gulp.start(task);
