// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart';

/**
 * Type of functions used to compute the contents of a set of generated files.
 * [pkgPath] is the path to the current package.
 */
typedef Map<String, FileContentsComputer> DirectoryContentsComputer(
    String pkgPath);

/**
 * Type of functions used to compute the contents of a generated file.
 * [pkgPath] is the path to the current package.
 */
typedef String FileContentsComputer(String pkgPath);

/**
 * Abstract base class representing behaviors common to generated files and
 * generated directories.
 */
abstract class GeneratedContent {
  /**
   * Check whether the [output] has the correct contents, and return true if it
   * does.  [pkgPath] is the path to the current package.
   */
  bool check(String pkgPath);

  /**
   * Replace the [output] with the correct contents.  [pkgPath] is the path to
   * the current package.
   */
  void generate(String pkgPath);

  /**
   * Get a [FileSystemEntity] representing the output file or directory.
   * [pkgPath] is the path to the current package.
   */
  FileSystemEntity output(String pkgPath);

  /**
   * Check that all of the [targets] are up to date.  If they are not, print
   * out a message instructing the user to regenerate them, and exit with a
   * nonzero error code.
   *
   * [pkgPath] is the path to the current package.  [generatorRelPath] is the
   * path to a .dart script the user may use to regenerate the targets.
   *
   * To avoid mistakes when run on Windows, [generatorRelPath] always uses
   * POSIX directory separators.
   */
  static void checkAll(String pkgPath, String generatorRelPath,
      Iterable<GeneratedContent> targets) {
    bool generateNeeded = false;
    for (GeneratedContent target in targets) {
      if (!target.check(pkgPath)) {
        print(
            '${target.output(pkgPath).absolute} does not have expected contents.');
        generateNeeded = true;
      }
    }
    if (generateNeeded) {
      print('Please regenerate using:');
      String executable = Platform.executable;
      String packageRoot = '';
      if (Platform.packageRoot != null) {
        packageRoot = ' --package-root=${Platform.packageRoot}';
      }
      String generateScript =
          join(pkgPath, joinAll(posix.split(generatorRelPath)));
      print('  $executable$packageRoot $generateScript');
      exit(1);
    } else {
      print('All generated files up to date.');
    }
  }

  /**
   * Regenerate all of the [targets].  [pkgPath] is the path to the current
   * package.
   */
  static void generateAll(String pkgPath, Iterable<GeneratedContent> targets) {
    for (GeneratedContent target in targets) {
      target.generate(pkgPath);
    }
  }
}

/**
 * Class representing a single output directory (either generated code or
 * generated HTML). No other content should exist in the directory.
 */
class GeneratedDirectory extends GeneratedContent {
  /**
   * The path to the directory that will have the generated content.
   */
  final String outputDirPath;

  /**
   * Callback function that computes the directory contents.
   */
  final DirectoryContentsComputer directoryContentsComputer;

  GeneratedDirectory(this.outputDirPath, this.directoryContentsComputer);

  @override
  bool check(String pkgPath) {
    Directory outputDirectory = output(pkgPath);
    Map<String, FileContentsComputer> map = directoryContentsComputer(pkgPath);
    try {
      for (String file in map.keys) {
        FileContentsComputer fileContentsComputer = map[file];
        String expectedContents = fileContentsComputer(pkgPath);
        File outputFile = new File(posix.join(outputDirectory.path, file));
        String actualContents = outputFile.readAsStringSync();
        // Normalize Windows line endings to Unix line endings so that the
        // comparison doesn't fail on Windows.
        actualContents = actualContents.replaceAll('\r\n', '\n');
        if (expectedContents != actualContents) {
          return false;
        }
      }
      int nonHiddenFileCount = 0;
      outputDirectory
          .listSync(recursive: false, followLinks: false)
          .forEach((FileSystemEntity fileSystemEntity) {
        if (fileSystemEntity is File &&
            !basename(fileSystemEntity.path).startsWith('.')) {
          nonHiddenFileCount++;
        }
      });
      if (nonHiddenFileCount != map.length) {
        // The number of files generated doesn't match the number we expected to
        // generate.
        return false;
      }
    } catch (e) {
      // There was a problem reading the file (most likely because it didn't
      // exist).  Treat that the same as if the file doesn't have the expected
      // contents.
      return false;
    }
    return true;
  }

  @override
  void generate(String pkgPath) {
    Directory outputDirectory = output(pkgPath);
    try {
      // delete the contents of the directory (and the directory itself)
      outputDirectory.deleteSync(recursive: true);
    } catch (e) {
      // Error caught while trying to delete the directory, this can happen if
      // it didn't yet exist.
    }
    // re-create the empty directory
    outputDirectory.createSync(recursive: true);

    // generate all of the files in the directory
    Map<String, FileContentsComputer> map = directoryContentsComputer(pkgPath);
    map.forEach((String file, FileContentsComputer fileContentsComputer) {
      File outputFile = new File(posix.join(outputDirectory.path, file));
      outputFile.writeAsStringSync(fileContentsComputer(pkgPath));
    });
  }

  @override
  Directory output(String pkgPath) =>
      new Directory(join(pkgPath, joinAll(posix.split(outputDirPath))));
}

/**
 * Class representing a single output file (either generated code or generated
 * HTML).
 */
class GeneratedFile extends GeneratedContent {
  /**
   * The output file to which generated output should be written, relative to
   * the "tool/spec" directory.  This filename uses the posix path separator
   * ('/') regardless of the OS.
   */
  final String outputPath;

  /**
   * Callback function which computes the file.
   */
  final FileContentsComputer computeContents;

  GeneratedFile(this.outputPath, this.computeContents);

  @override
  bool check(String pkgPath) {
    File outputFile = output(pkgPath);
    String expectedContents = computeContents(pkgPath);
    try {
      String actualContents = outputFile.readAsStringSync();
      // Normalize Windows line endings to Unix line endings so that the
      // comparison doesn't fail on Windows.
      actualContents = actualContents.replaceAll('\r\n', '\n');
      return expectedContents == actualContents;
    } catch (e) {
      // There was a problem reading the file (most likely because it didn't
      // exist).  Treat that the same as if the file doesn't have the expected
      // contents.
      return false;
    }
  }

  @override
  void generate(String pkgPath) {
    output(pkgPath).writeAsStringSync(computeContents(pkgPath));
  }

  @override
  File output(String pkgPath) =>
      new File(join(pkgPath, joinAll(posix.split(outputPath))));
}
