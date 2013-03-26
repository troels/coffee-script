# This file contains the common helper functions that we'd like to share among
# the **Lexer**, **Rewriter**, and the **Nodes**. Merge objects, flatten
# arrays, count characters, that sort of thing.

# Peek at the beginning of a given string to see if it matches a sequence.
exports.starts = (string, literal, start) ->
  literal is string.substr start, literal.length

# Peek at the end of a given string to see if it matches a sequence.
exports.ends = ends = (string, literal, back) ->
  len = literal.length
  literal is string.substr string.length - len - (back or 0), len

# Repeat a string `n` times.
exports.repeat = repeat = (str, n) ->
  # Use clever algorithm to have O(log(n)) string concatenation operations.
  res = ''
  while n > 0
    res += str if n & 1
    n >>>= 1
    str += str
  res

# Trim out all falsy values from an array.
exports.compact = (array) ->
  item for item in array when item

# Count the number of occurrences of a string in a string.
exports.count = (string, substr) ->
  num = pos = 0
  return 1/0 unless substr.length
  num++ while pos = 1 + string.indexOf substr, pos
  num

# Merge objects, returning a fresh copy with attributes from both sides.
# Used every time `Base#compile` is called, to allow properties in the
# options hash to propagate down the tree without polluting other branches.
exports.merge = (options, overrides) ->
  extend (extend {}, options), overrides

# Extend a source object with the properties of another object (shallow copy).
extend = exports.extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

# Return a flattened version of an array.
# Handy for getting a list of `children` from the nodes.
exports.flatten = flatten = (array) ->
  flattened = []
  for element in array
    if element instanceof Array
      flattened = flattened.concat flatten element
    else
      flattened.push element
  flattened

# Delete a key from an object, returning the value. Useful when a node is
# looking for a particular method in an options hash.
exports.del = (obj, key) ->
  val =  obj[key]
  delete obj[key]
  val

# Gets the last item of an array(-like) object.
exports.last = last = (array, back) -> array[array.length - (back or 0) - 1]

exports.butlast = butlast = (array, back) -> array[0 ... array.length - (back or 0) - 1]

# Typical Array::some
exports.some = Array::some ? (fn) ->
  return true for e in this when fn e
  false

# Simple function for inverting Literate CoffeeScript code by putting the
# documentation in comments, and bumping the actual code back out to the edge ...
# producing a string of CoffeeScript code that can be compiled "normally".
exports.invertLiterate = (code) ->
  lines = for line in code.split('\n')
    if match = (/^([ ]{4}|\t)/).exec line
      line[match[0].length..]
    else
      '# ' + line
  lines.join '\n'

# This returns a function which takes an object as a parameter, and if that
# object is an AST node, updates that object's locationData.
# The object is returned either way.
exports.addLocationDataFn = (first, last) ->
    (obj) ->
      return obj if not obj?.updateLocationDataIfMissing

      {first_line, first_column, last_line, last_column} = first
      {last_line, last_column} = last if last?

      obj.updateLocationDataIfMissing
          first_line:   first_line
          first_column: first_column
          last_line:    last_line
          last_column:  last_column

# Convert jison location data to a string.
# `obj` can be a token, or a locationData.
exports.locationDataToString = (obj) ->
    if obj?[2]?.first_line? # A token
      ld = obj[2]
    else if obj?.first_line? # Pure locationData
      ld = obj
    else
      return "No location data"

    "#{ld.first_line + 1}:#{ld.first_column + 1}-#{ld.last_line + 1}:#{ld.last_column + 1}"

# Strip '.coffee.md' if that's the extension
# otherwise strip suffix starting at last '.'
exports.stripExtension = (fn) ->
  ext = ".coffee.md"
  return fn.substr 0, fn.length - ext.length if ends fn, ext
  return fn if '.' not in fn

  butlast(fn.split '.').join '.'

# A `.coffee.md` compatible version of `basename`, that returns the file sans-extension.

# Determine if a filename represents a CoffeeScript file.
exports.isCoffee = (file) -> /\.((lit)?coffee|coffee\.md)$/.test file

# Determine if a filename represents a Literate CoffeeScript file.
exports.isLiterate = (file) -> /\.(litcoffee|coffee\.md)$/.test file

# Throws a SyntaxError with a source file location data attached to it in a
# property called `location`.
exports.throwSyntaxError = (message, location) ->
  location.last_line ?= location.first_line
  location.last_column ?= location.first_column
  error = new SyntaxError message
  error.location = location
  throw error

# Creates a nice error message like, following the "standard" format
# <filename>:<line>:<col>: <message> plus the line with the error and a marker
# showing where the error is.
exports.prettyErrorMessage = (error, fileName, code, useColors) ->
  return error.stack or "#{error}" unless error.location

  {first_line, first_column, last_line, last_column} = error.location
  codeLine = code.split('\n')[first_line]
  start    = first_column
  # Show only the first line on multi-line errors.
  end      = if first_line is last_line then last_column + 1 else codeLine.length
  marker   = repeat(' ', start) + repeat('^', end - start)

  if useColors
    colorize  = (str) -> "\x1B[1;31m#{str}\x1B[0m"
    codeLine = codeLine[...start] + colorize(codeLine[start...end]) + codeLine[end..]
    marker    = colorize marker

  message = """
  #{fileName}:#{first_line + 1}:#{first_column + 1}: error: #{error.message}
  #{codeLine}
  #{marker}
            """

  # Uncomment to add stacktrace.
  #message += "\n#{error.stack}"

  message
