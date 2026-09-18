/// Single-quotes [value] for POSIX shells; embedded quotes stay literal.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
