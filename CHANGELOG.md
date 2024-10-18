## HEAD (unreleased)

## 2.0.1

- Fix CLI failure when shipped with default gems. (https://github.com/ruby/syntax_suggest/pull/226 and https://github.com/ruby/syntax_suggest/pull/227)

## 2.0.0

- Changed: No longer supports EOL versions of Ruby. (https://github.com/ruby/syntax_suggest/pull/210)
- Added: Support prism parser (https://github.com/ruby/syntax_suggest/pull/208).
- Added: Handle Ruby 3.3 new eval source location format (https://github.com/ruby/syntax_suggest/pull/200).

## 1.1.0

- Handle if/else with comment or empty line in branch (https://github.com/ruby/syntax_suggest/pull/193)
- Use `SYNTAX_SUGGEST_DEBUG` instead of `DEBUG` env var value in timeout warning message (https://github.com/ruby/syntax_suggest/pull/194)
- Reduce line output for increased clarity (https://github.com/ruby/syntax_suggest/pull/190)

## 1.0.4

- Fix rendering a file without a newline ending (https://github.com/ruby/syntax_suggest/pull/182)

## 1.0.3

- Output improvement: Handle methods with only newlines or comments in them (https://github.com/ruby/syntax_suggest/pull/179)
- No longer shows the detail of monkey patch as the document (https://github.com/ruby/syntax_suggest/pull/174)
- Drop CI for Ruby 3.2.0-rc1, now that 3.2.0 is available (https://github.com/ruby/syntax_suggest/pull/172)

## 1.0.2

- Drop support for Ruby 3.2.0 preview, now that 3.2.0-rc1 is available (https://github.com/ruby/syntax_suggest/pull/165)
- Native support of `SyntaxError#path`, support 3.2.0-preview3 will be dropped with the release of 3.2.0-preview4 (https://github.com/ruby/syntax_suggest/pull/164)
- Added dependabot for GitHub Actions (https://github.com/ruby/syntax_suggest/pull/160)

## 1.0.1

- Replace `❯` with `>` in error output for compatability with more fonts (https://github.com/ruby/syntax_suggest/pull/161)

## 1.0.0 (Library renamed to syntax_suggest )

- [Breaking] Output "Syntax OK" will no longer be output when `syntax_suggest` is fired due to a syntax error. (https://github.com/ruby/syntax_suggest/pull/158)
- [Breaking] Rename `dead_end` to `syntax_suggest` (https://github.com/zombocom/dead_end/pull/154)
- [Breaking] Lazy loading moved from `autoload` to manually checking for constants and requiring `dead_end/api`. To manually use any SyntaxSuggest internals you MUST require `dead_end/api`, otherwise it will be lazy loaded on syntax error (https://github.com/zombocom/dead_end/pull/148)
- Default to highlighted output on Ruby 3.2 (https://github.com/zombocom/dead_end/pull/150)
- Debug functionality enabled by `DEBUG=1` env var is now under `SYNTAX_SUGGEST_DEBUG=1`. Note this is not a stable interface or feature. Output content is subject to change without major version change (https://github.com/zombocom/dead_end/pull/149)
- Enable/Disable dead_end by using the `dead_end` kwarg in `detailed_message` (https://github.com/zombocom/dead_end/pull/147)
- Respect `highlight` kwarg in Ruby 3.2's `detailed_message` to enable/disable control characters (https://github.com/zombocom/dead_end/pull/147)
- Added workarounds for running on ruby/ruby repo (https://github.com/ruby/syntax_suggest/pull/156)

## dead_end 4.0.0

- Code that does not have an associated file (eval and streamed) no longer produce a warning saying that the file could not be found. To produce a warning with these code types run with DEBUG=1 environment variable. (https://github.com/zombocom/dead_end/pull/143)
- [Breaking] Lazy load SyntaxSuggest internals only if there is a Syntax error. Use `require "dead_end"; require "dead_end/api"` to load eagerly all internals. Otherwise `require "dead_end"` will set up an autoload for the first time the SyntaxSuggest module is used in code. This should only happen on a syntax error. (https://github.com/zombocom/dead_end/pull/142)
- Monkeypatch `SyntaxError#detailed_message` in Ruby 3.2+ instead of `require`, `load`, and `require_relative` (https://github.com/zombocom/dead_end/pull/139)

## dead_end 3.1.2

- Fixed internal class AroundBlockScan, minor changes in outputs (https://github.com/zombocom/dead_end/pull/131)

## dead_end 3.1.1

- Fix case where Ripper lexing identified incorrect code as a keyword (https://github.com/zombocom/dead_end/pull/122)

## dead_end 3.1.0

- Add support for Ruby 3.1 by updating `require_relative` logic (https://github.com/zombocom/dead_end/pull/120)
- Requiring `dead_end/auto` is now deprecated please require `dead_end` instead (https://github.com/zombocom/dead_end/pull/119)
- Requiring `dead_end/api` now loads code without monkeypatching core extensions (https://github.com/zombocom/dead_end/pull/119)
- The interface `SyntaxSuggest.handle_error` is declared public and stable (https://github.com/zombocom/dead_end/pull/119)

## dead_end 3.0.3

- Expand explanations coming from additional Ripper errors (https://github.com/zombocom/dead_end/pull/117)
- Fix explanation involving shorthand syntax for literals like `%w[]` and `%Q{}` (https://github.com/zombocom/dead_end/pull/116)

## dead_end 3.0.2

- Fix windows filename detection (https://github.com/zombocom/dead_end/pull/114)
- Update links on readme and code of conduct (https://github.com/zombocom/dead_end/pull/107)

## dead_end 3.0.1

- Fix CLI parsing when flags come before filename (https://github.com/zombocom/dead_end/pull/102)

## dead_end 3.0.0

- [Breaking] CLI now outputs to STDOUT instead of STDERR (https://github.com/zombocom/dead_end/pull/98)
- [Breaking] Remove previously deprecated `require "dead_end/fyi"` interface (https://github.com/zombocom/dead_end/pull/94)
- Fix double output bug (https://github.com/zombocom/dead_end/pull/99)
- Fix bug causing poor results (fix #95, fix #88) (https://github.com/zombocom/dead_end/pull/96)
- SyntaxSuggest is now fired on EVERY syntax error (https://github.com/zombocom/dead_end/pull/94)
- Output format changes:
  - Parse errors emitted per-block rather than for the whole document (https://github.com/zombocom/dead_end/pull/94)
  - The "banner" is now based on lexical analysis rather than parser regex (fix #68, fix #87) (https://github.com/zombocom/dead_end/pull/96)

## dead_end 2.0.2

- Don't print terminal color codes when output is not tty (https://github.com/zombocom/dead_end/pull/91)

## dead_end 2.0.1

- Reintroduce Ruby 2.5 support (https://github.com/zombocom/dead_end/pull/90)
- Support naked braces/brackets/parens, invert labels on banner (https://github.com/zombocom/dead_end/pull/89)
- Handle mismatched end when using rescue without begin (https://github.com/zombocom/dead_end/pull/83)
- CLI returns non-zero exit code when syntax error is found (https://github.com/zombocom/dead_end/pull/86)
- Let -v respond with gem version instead of 'unknown' (https://github.com/zombocom/dead_end/pull/82)

## dead_end 2.0.0

- Support "endless" oneline method definitions for Ruby 3+ (https://github.com/zombocom/dead_end/pull/80)
- Reduce timeout to 1 second (https://github.com/zombocom/dead_end/pull/79)
- Logically consecutive lines (such as chained methods are now joined) (https://github.com/zombocom/dead_end/pull/78)
- Output improvement for cases where the only line is an single `end` (https://github.com/zombocom/dead_end/pull/78)

## dead_end 1.2.0

- Output improvements via less greedy unmatched kw capture https://github.com/zombocom/dead_end/pull/73
- Remove NoMethodError patching instead use https://github.com/ruby/error_highlight/ (https://github.com/zombocom/dead_end/pull/71)

## dead_end 1.1.7

- Fix sinatra support for `require_relative` (https://github.com/zombocom/dead_end/pull/63)

## dead_end 1.1.6

- Consider if syntax error caused an unexpected variable instead of end (https://github.com/zombocom/dead_end/pull/58)

## dead_end 1.1.5

- Parse error once and not twice if there's more than one available (https://github.com/zombocom/dead_end/pull/57)

## dead_end 1.1.4

- Avoid including demo gif in built gem (https://github.com/zombocom/dead_end/pull/53)

## dead_end 1.1.3

- Add compatibility with zeitwerk (https://github.com/zombocom/dead_end/pull/52)

## dead_end 1.1.2

- Namespace Kernel method aliases (https://github.com/zombocom/dead_end/pull/51)

## dead_end 1.1.1

- Safer NoMethodError annotation (https://github.com/zombocom/dead_end/pull/48)

## dead_end 1.1.0

- Annotate NoMethodError in non-production environments (https://github.com/zombocom/dead_end/pull/46)
- Do not count trailing if/unless as a keyword (https://github.com/zombocom/dead_end/pull/44)

## dead_end 1.0.2

- Fix bug where empty lines were interpreted to have a zero indentation (https://github.com/zombocom/dead_end/pull/39)
- Better results when missing "end" comes at the end of a capturing block (such as a class or module definition) (https://github.com/zombocom/dead_end/issues/32)

## dead_end 1.0.1

- Fix performance issue when evaluating multiple block combinations (https://github.com/zombocom/dead_end/pull/35)

## dead_end 1.0.0

- Gem name changed from `syntax_search` to `dead_end` (https://github.com/zombocom/syntax_search/pull/30)
- Moved `syntax_search/auto` behavior to top level require (https://github.com/zombocom/syntax_search/pull/30)
- Error banner now indicates when missing a `|` or `}` in addition to `end` (https://github.com/zombocom/syntax_search/pull/29)
- Trailing slashes are now handled (joined) before the code search (https://github.com/zombocom/syntax_search/pull/28)

## dead_end 0.2.0

- Simplify large file output so minimal context around the invalid section is shown (https://github.com/zombocom/syntax_search/pull/26)
- Block expansion is now lexically aware of keywords (def/do/end etc.) (https://github.com/zombocom/syntax_search/pull/24)
- Fix bug where not all of a source is lexed which is used in heredoc detection/removal (https://github.com/zombocom/syntax_search/pull/23)

## dead_end 0.1.5

- Strip out heredocs in documents first (https://github.com/zombocom/syntax_search/pull/19)

## dead_end 0.1.4

- Parser gem replaced with Ripper (https://github.com/zombocom/syntax_search/pull/17)

## dead_end 0.1.3

- Internal refactor (https://github.com/zombocom/syntax_search/pull/13)

## dead_end 0.1.2

- Codeblocks in output are now indented with 4 spaces and "code fences" are removed (https://github.com/zombocom/syntax_search/pull/11)
- "Unmatched end" and "missing end" not generate different error text instructions (https://github.com/zombocom/syntax_search/pull/10)

## dead_end 0.1.1

- Fire search on both unexpected end-of-input and unexected end (https://github.com/zombocom/syntax_search/pull/8)

## dead_end 0.1.0

- Initial release
