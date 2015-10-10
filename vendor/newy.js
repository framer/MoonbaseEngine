var through2 = require('through2');
var fs = require("fs");
var path = require('path');
var colors = require('colors');
var gutil = require('gulp-util');
var PluginError = gutil.PluginError;

const PLUGIN_NAME = 'gulp-newy';

function constructDestwCallBack(absSrcFile, callback) {
    var projectDir = path.resolve(__dirname + "../../../../");
    var srcFile = path.basename(absSrcFile);
    destination = callback(projectDir, srcFile, absSrcFile);
    if (fs.existsSync(destination)) {
        return destination;
    } else {
        return false;
    }

}
 
function compareFileTimes(destinationFile, srcFile) {
    destinationFile = fs.statSync(destinationFile).mtime;
    srcFile = fs.statSync(srcFile).mtime;
    return (srcFile > destinationFile); 
}

function errorCheckArg(args) {
  if (typeof(args[0]) !== 'function') {
      throw new PluginError(PLUGIN_NAME, "ERROR! this plugin requires a callback function, Jack!");
  }
}

function consoleOut(absSrcFile, destinationFile) {
    console.log("-------------------- Newy Message ------------------" .magenta);
    console.log("File " .magenta + path.basename(absSrcFile) .white + 
			" is new/newer then " .magenta + path.basename(destinationFile)
            .white);
    console.log("----------------------------------------------------" .magenta);
}

function newy(callback) {
    var destinationFile;
    errorCheckArg(arguments);
    return through2.obj(function(file, enc, next) {
        var pipeFileThrough = true;
        var streamObject = file.clone();
        var absSrcFile = streamObject.history[0];

        destinationFile = constructDestwCallBack(absSrcFile, callback);
        if (destinationFile) {
            pipeFileThrough = compareFileTimes(destinationFile, absSrcFile);
        }
        if (pipeFileThrough) {
            // consoleOut(absSrcFile, destinationFile);
            this.push(streamObject);
        }
        next();
    });
}

module.exports = newy;

