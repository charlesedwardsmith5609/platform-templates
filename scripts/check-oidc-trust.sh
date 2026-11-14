#!/usr/bin/env bash
# Structural check of IAM trust policies that trust token.actions.githubusercontent.com.
#
# Every Allow statement in a policy that names the host must have, under
# StringEquals or StringLike (case-insensitive, ForAnyValue: allowed):
#   - a "<host>:sub" condition whose values are non-empty and contain no * or ?
#   - a "<host>:aud" condition whose values are non-empty and contain no * or ?
# It rejects negated operators (StringNot*), ForAllValues:, and ...IfExists on sub.
#
# Inputs: .json, .json.tpl (parsed with jq) and .tf, .hcl (converted to JSON by a
# small tokenizer, then checked the same way). A .tf or .hcl file that names the
# host but uses ":sub" in a form this script cannot classify fails.
#
# Usage: scripts/check-oidc-trust.sh [--require-match] [--skip-testdata] [root]
#   --require-match  exit 1 when no file trusts the host
#   --skip-testdata  do not scan directories named testdata (scanned by default)
# Exit codes: 0 pass, 1 findings, 2 usage or read error.
set -euo pipefail

usage() {
  echo "usage: $0 [--require-match] [--skip-testdata] [root]" >&2
  exit 2
}

require_match=0
skip_testdata=0
ROOT=""
for arg in "$@"; do
  case "${arg}" in
    --require-match) require_match=1 ;;
    --skip-testdata) skip_testdata=1 ;;
    -*) usage ;;
    *)
      [[ -z "${ROOT}" ]] || usage
      ROOT="${arg}"
      ;;
  esac
done
if [[ -z "${ROOT}" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
if [[ ! -d "${ROOT}" || ! -r "${ROOT}" ]]; then
  echo "cannot read ${ROOT}" >&2
  exit 2
fi
for tool in jq awk; do
  command -v "${tool}" >/dev/null || {
    echo "cannot run: ${tool} not found" >&2
    exit 2
  }
done

host="token.actions.githubusercontent.com"

# HCL (the subset used for policies) to JSON. Blocks become "@cN" members with
# "@type" and "@labels". Expressions become the string "@@EXPR@@". Any construct it
# does not understand sets an error and the file is reported as unclassifiable.
read -r -d '' HCL2JSON <<'AWK' || true
function err(m) { if (ERR == "") ERR = m }
function lstr(x) { return tolower(x) }
function scan_string(s, i,    n, c) {
  # s[i] is an opening quote; return index of the closing quote, or 0
  n = length(s); i++
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { i += 2; continue }
    if (c == "\"") return i
    if (c == "$" && substr(s, i + 1, 1) == "{" ) { i = skip_interp(s, i + 1); if (i == 0) return 0; continue }
    i++
  }
  return 0
}
function skip_interp(s, i,    n, c, d) {
  # s[i] is "{" of ${ ; return index after the matching "}", or 0
  n = length(s); d = 0
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\"") { i = scan_string(s, i); if (i == 0) return 0; i++; continue }
    if (c == "{") d++
    else if (c == "}") { d--; if (d == 0) return i + 1 }
    i++
  }
  return 0
}
function addtok(t, v) { NT++; TT[NT] = t; TV[NT] = v }
function tokenize(s,    i, n, c, c2, j, str, id, lines, k, line, tag, body, rest) {
  n = length(s); i = 1
  while (i <= n && ERR == "") {
    c = substr(s, i, 1); c2 = substr(s, i, 2)
    if (c ~ /[ \t\r\n]/) { i++; continue }
    if (c == "#" || c2 == "//") { j = index(substr(s, i), "\n"); if (j == 0) break; i += j; continue }
    if (c2 == "/*") { j = index(substr(s, i + 2), "*/"); if (j == 0) { err("unterminated comment"); break } i += j + 3; continue }
    if (c == "\"") {
      j = scan_string(s, i)
      if (j == 0) { err("unterminated string"); break }
      str = substr(s, i, j - i + 1)
      if (index(lstr(str), ":sub") > 0) TEXTSUBS++
      if (index(lstr(str), host) > 0) HOSTSTRS++
      addtok("S", str); i = j + 1; continue
    }
    if (c2 == "<<") {
      rest = substr(s, i + 2)
      if (match(rest, /^-?[A-Za-z_][A-Za-z0-9_]*/)) {
        tag = substr(rest, 1, RLENGTH); sub(/^-/, "", tag)
        i += 2 + RLENGTH
        j = index(substr(s, i), "\n"); if (j == 0) { err("unterminated heredoc"); break }
        i += j; body = ""
        while (i <= n) {
          j = index(substr(s, i), "\n")
          if (j == 0) { line = substr(s, i); i = n + 1 } else { line = substr(s, i, j - 1); i += j }
          k = line; gsub(/^[ \t]+|[ \t\r]+$/, "", k)
          if (k == tag) { tag = ""; break }
          body = body line "\n"
        }
        if (tag != "") { err("unterminated heredoc"); break }
        if (index(lstr(body), ":sub") > 0 || index(lstr(body), host) > 0) err("policy text in a heredoc")
        addtok("H", ""); continue
      }
      err("unsupported token <<"); break
    }
    if (c ~ /[={}\[\](),:]/) { addtok("P", c); i++; continue }
    if (match(substr(s, i), /^[0-9][0-9.eE+-]*/)) { addtok("N", substr(s, i, RLENGTH)); i += RLENGTH; continue }
    if (match(substr(s, i), /^[A-Za-z_][A-Za-z0-9_.-]*/)) { addtok("I", substr(s, i, RLENGTH)); i += RLENGTH; continue }
    err("unsupported token " c); break
  }
}
function isp(ch) { return (P <= NT && TT[P] == "P" && TV[P] == ch) }
function keyjson(   v) { v = (TT[P] == "S") ? TV[P] : "\"" TV[P] "\""; P++; return v }
function skip_parens(   d) {
  d = 0
  while (P <= NT) {
    if (isp("(")) d++
    else if (isp(")")) { d--; if (d == 0) { P++; return } }
    P++
  }
  err("unbalanced parentheses")
}
function parse_value(   v, out, k, val, nm) {
  if (ERR != "" || P > NT) { err("unexpected end"); return "null" }
  if (TT[P] == "S" || TT[P] == "N") { v = TV[P]; P++; return v }
  if (TT[P] == "H") { P++; return "\"@@HEREDOC@@\"" }
  if (isp("{")) {
    P++; out = ""
    while (ERR == "") {
      while (isp(",")) P++
      if (isp("}")) { P++; break }
      if (P > NT || (TT[P] != "S" && TT[P] != "I")) { err("bad object key"); break }
      k = keyjson()
      if (isp("=") || isp(":")) P++; else { err("expected = in object"); break }
      val = parse_value()
      out = out (out == "" ? "" : ",") k ":" val
    }
    return "{" out "}"
  }
  if (isp("[")) {
    P++; out = ""
    while (ERR == "") {
      if (isp("]")) { P++; break }
      val = parse_value()
      out = out (out == "" ? "" : ",") val
      if (isp(",")) P++
      else if (!isp("]")) { err("unsupported list element"); break }
    }
    return "[" out "]"
  }
  if (TT[P] == "I") {
    nm = TV[P]; P++
    if (nm == "true" || nm == "false" || nm == "null") return nm
    if (nm == "jsonencode" && isp("(")) {
      P++; val = parse_value()
      if (isp(",")) P++
      if (isp(")")) P++; else err("bad jsonencode call")
      return val
    }
    if (isp("(")) skip_parens()
    return "\"@@EXPR@@\""
  }
  err("unsupported value"); return "null"
}
function parse_body(top,   out, key, labels, child, m) {
  out = ""
  while (P <= NT && ERR == "") {
    if (isp("}")) { if (top) err("unbalanced }"); break }
    if (TT[P] != "S" && TT[P] != "I") { err("bad body token"); break }
    key = keyjson()
    if (isp("=")) {
      P++; m = key ":" parse_value()
    } else {
      labels = ""
      while (P <= NT && (TT[P] == "S" || TT[P] == "I")) { labels = labels (labels == "" ? "" : ",") keyjson() }
      if (!isp("{")) { err("expected block"); break }
      P++; child = parse_body(0)
      if (isp("}")) P++; else { err("unterminated block"); break }
      CN++
      m = "\"@c" CN "\":{\"@type\":" key ",\"@labels\":[" labels "]" (child == "" ? "" : "," child) "}"
    }
    out = out (out == "" ? "" : ",") m
  }
  return out
}
{ SRC = SRC $0 "\n" }
END {
  host = "token.actions.githubusercontent.com"
  P = 1
  tokenize(SRC)
  body = ""
  if (ERR == "") body = parse_body(1)
  if (ERR == "" && P <= NT) err("trailing tokens")
  if (ERR != "") { printf "{\"err\":\"%s\"}\n", ERR; exit 0 }
  printf "{\"textsubs\":%d,\"hoststrs\":%d,\"body\":{%s}}\n", TEXTSUBS, HOSTSTRS, body
}
AWK

read -r -d '' JQPROG <<'JQ' || true
def vals: if type == "array" then . elif type == "null" then [] else [.] end;
def parseop:
  ascii_downcase as $o
  | ($o | sub("^(foranyvalue|forallvalues):"; "")) as $b
  | { all: ($o | startswith("forallvalues:")),
      ifx: ($b | endswith("ifexists")),
      base: ($b | sub("ifexists$"; "")) };
def plain: type == "string" and length > 0 and (contains("*") | not) and (contains("?") | not)
  and (contains("@@EXPR@@") | not) and (contains("${") | not);
# entries for one claim suffix: {op, parsed, key, values}
def claims($suf):
  [ (.Condition // {}) | (if type == "object" then . else {"@bad": {}} end)
    | to_entries[] | .key as $op | .value as $m
    | if ($m | type) != "object" then {op: $op, bad: "condition value not classifiable", key: ""}
      else ($m | to_entries[] | select(.key | ascii_downcase | endswith(":" + $suf))
        | {op: $op, key: .key, p: ($op | parseop), values: (.value | vals)}) end ];
def claim_problems($suf):
  claims($suf)
  | map(
      if .bad then .bad
      elif .p.all then "ForAllValues on \($suf) (\(.op))"
      elif .p.ifx then "IfExists on \($suf) (\(.op))"
      elif (.p.base == "stringequals" or .p.base == "stringlike") | not then "unsupported operator on \($suf): \(.op)"
      elif (.values | length) == 0 or (.values | all(plain) | not) then "wildcard or empty \($suf): \(.values | tojson)"
      else empty end);
def good_claims($suf):
  [ claims($suf)[] | select(.bad == null and (.p.all | not) and (.p.ifx | not)
      and (.p.base == "stringequals" or .p.base == "stringlike")
      and (.values | length) > 0 and (.values | all(plain))) ] | length;
def subcount: [ (.Condition // {}) | objects | .[]? | objects | keys[] | select(ascii_downcase | contains(":sub")) ] | length;

def statements_json:
  [ .. | objects | select(has("Statement")) | .Statement | (if type == "array" then .[] else . end) | select(type == "object") ];
def statements_hcl:
  [ .. | objects | select(."@type" == "data" and ((."@labels" // [])[0] == "\"aws_iam_policy_document\"" or (."@labels" // [])[0] == "aws_iam_policy_document"))
    | to_entries[] | select(.key | startswith("@c")) | .value
    | select(."@type" == "statement")
    | { Effect: (.effect // "Allow"),
        Condition: ([ to_entries[] | select(.key | startswith("@c")) | .value | select(."@type" == "condition") ]
          | reduce .[] as $c ({}; .[($c.test | tostring)][($c.variable | tostring)] += ($c.values | vals))) } ];
def odd_blocks:
  [ .. | objects | select(."@type" == "data" and ((."@labels" // [])[0] | tostring | contains("aws_iam_policy_document")))
    | to_entries[] | select(.key | startswith("@c")) | .value | select(."@type" != "statement") ] | length;

. as $doc
| if has("err") then
    ["unclassifiable: could not read the file as policy data (\(.err))"]
  else
    (.body) as $b
    | ($b | statements_json + statements_hcl) as $stmts
    | (if has("textsubs") then .textsubs
       else ([$b | .. | strings | select(ascii_downcase | contains(":sub"))] | length)
          + ([$b | paths | last | select(type == "string") | select(ascii_downcase | contains(":sub"))] | length) end) as $total
    | ([$stmts[] | subcount] | add // 0) as $classified
    | (if has("hoststrs") then .hoststrs
       else ($b | tojson | ascii_downcase | [match($host; "g")] | length) end) as $mentions
    | if $mentions == 0 then ["@nomatch"]
      else
        ( if ($stmts | length) == 0 then ["unclassifiable: names the host but no policy statement was found"] else [] end )
        + ( if ($b | odd_blocks) > 0 then ["unclassifiable: unsupported block in aws_iam_policy_document"] else [] end )
        + ( if $total != $classified then ["unclassifiable: \":sub\" used in \($total - $classified) place(s) the checker cannot classify"] else [] end )
        + [ $stmts[] | select((.Effect | tostring | ascii_downcase) != "deny")
            | (claim_problems("sub") + claim_problems("aud")) as $probs
            | ( $probs[] ),
              ( if good_claims("sub") == 0 and (claim_problems("sub") | length) == 0 then "no sub condition in an Allow statement" else empty end ),
              ( if good_claims("aud") == 0 and (claim_problems("aud") | length) == 0 then "no aud condition in an Allow statement" else empty end ) ]
      end
  end
| .[]
JQ

failures=0
checked=0
findfile() { # print findings for one file; sets nothing, prints lines
  local file="$1" kind="$2" json
  if [[ "${kind}" == json ]]; then
    if ! json="$(jq -c '{body: .}' "${file}" 2>/dev/null)"; then
      printf '{"err":"invalid JSON"}'
      return
    fi
    printf '%s' "${json}"
  else
    awk "${HCL2JSON}" "${file}"
  fi
}

while IFS= read -r -d '' file; do
  rel="${file#"${ROOT}"/}"
  if [[ "${skip_testdata}" -eq 1 ]]; then
    case "${rel}" in
      testdata/* | */testdata/*) continue ;;
    esac
  fi
  if [[ ! -r "${file}" ]]; then
    echo "cannot read ${file}" >&2
    exit 2
  fi
  grep -qiF -- "${host}" "${file}" || continue
  case "${file}" in
    *.json | *.json.tpl) kind=json ;;
    *) kind=hcl ;;
  esac
  prepared="$(findfile "${file}" "${kind}")"
  if ! results="$(jq -r --arg host "${host}" "${JQPROG}" <<<"${prepared}" 2>&1)"; then
    results="unclassifiable: checker could not evaluate the file"
  fi
  if [[ "${results}" == "@nomatch" ]]; then
    continue
  fi
  checked=$((checked + 1))
  if [[ -n "${results}" ]]; then
    while IFS= read -r line; do
      echo "${file}: ${line}" >&2
      failures=$((failures + 1))
    done <<<"${results}"
  fi
done < <(find "${ROOT}" -type f ! -path '*/.git/*' ! -path '*/.terraform/*' \
  \( -name '*.tf' -o -name '*.json' -o -name '*.hcl' -o -name '*.json.tpl' \) -print0 | sort -z)

if [[ "${checked}" -eq 0 ]]; then
  echo "oidc trust check: no file trusts ${host}" >&2
  if [[ "${require_match}" -eq 1 ]]; then
    exit 1
  fi
  exit 0
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "oidc trust check failed: ${failures} finding(s) in ${checked} file(s)" >&2
  exit 1
fi

echo "oidc trust check passed (${checked} file(s) trust ${host} with a specific sub and aud)"
