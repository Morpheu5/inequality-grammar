@{%

import _cloneDeep from 'lodash/cloneDeep'
import _isEmpty from 'lodash/isEmpty'
import _isEqual from 'lodash/isEqual'
import _map from 'lodash/map'
import _mapValues from 'lodash/mapValues'
import _omit from 'lodash/omit'
import _reduceRight from 'lodash/reduceRight'

import { _simplify, _findRightmost } from '../src/utils'

let _window = null
try {
    _window = window
} catch (error) {
    _window = { innerWidth: 800, innerHeight: 600 }
}

/* Main point of entry. This function sets up the outer shell of the
   Inequality AST with placeholder data that will then be properly filled in
   by Inequality's headless parser.

   The `_simplify()`` function avoids unnecessarily nested parentheses.
 */
const processMain = (d) => {
    const main = _cloneDeep(d[1])
    main.position = { x: _window.innerWidth/4, y: _window.innerHeight/3 }
    main.expression = { latex: "", python: "" }
    return _simplify(main)
}

/* This is an alternative main point of entry for when we want to parse
   expressions that contain two sides joined by a relation symbol, such as
   equalities and inequalities.

   This one also sets up the outer shell of the Inequality AST because it
   operates at the same level as `processMain()`, so it has to perform a
   similar job.
 */
const processRelation = (d) => {
    let lhs = _cloneDeep(d[1])
    let rhs = _cloneDeep(d[5])
    let relText = d[3].text === '==' ? '=' : d[3].text
    let relation = { type: 'Relation', properties: { relation: relText }, children: { right: rhs } }
    let r = _findRightmost(lhs)
    r.children['right'] = relation
    lhs = _simplify(lhs)
    return { ...lhs, position: { x: _window.innerWidth/4, y: _window.innerHeight/3 }, expression: { latex: "", python: "" } }
}

/* Processes round brackets. For simplicity, we only support round brackets
   here. The only job of this function is to enclose its parsed argument in
   a round Brackets object. Any nested brackets are taken care of elsewhere.
 */
const processBrackets = (d) => {
    const arg = d[2] //_cloneDeep(d[2])
    return { type: 'Brackets', properties: { type: 'round' }, children: { argument: arg } }
}

/* Process Boolean logical binary operations. */
const processBinaryOperation = (d) => {
    const lhs = _cloneDeep(d[0])
    const rhs = _cloneDeep(d[d.length-1])
    const r = _findRightmost(lhs)
    let operation = '';
    switch(d[2].toLowerCase()) {
        case 'AND':
        case 'and':
        case '&':
        case '∧':
        case '.':
            operation = 'and'
            break
        case 'OR':
        case 'or':
        case '|':
        case '∨':
        case 'v':
        case '+':
            operation = 'or'
            break
        case 'XOR':
        case 'xor':
        case '^':
        case '⊻':
            operation = 'xor'
            break
        default:
            operation = ''
    }
    r.children['right'] = { type: 'LogicBinaryOperation', properties: { operation }, children: { right: rhs } }
    return lhs
}

/* Process Not operator. */
const processNot = (d) => {
    return { type: 'LogicNot', children: { argument: d[2] } }
}


%}

main -> _ AS _              {% processMain %}
      | _ AS _ "=" _ AS _   {% processRelation %} 

# OR
AS -> AS _ "OR" _ MD        {% processBinaryOperation %}
    | AS _ "or" _ MD        {% processBinaryOperation %}
    | AS _  "|" _ MD        {% processBinaryOperation %}
    | AS _  "∨" _ MD        {% processBinaryOperation %}
    | AS _  "v" _ MD        {% processBinaryOperation %}
    | AS _  "+" _ MD        {% processBinaryOperation %}
    | MD                    {% id %}

# AND
MD -> MD _ "AND" _ XOR      {% processBinaryOperation %}
    | MD _ "and" _ XOR      {% processBinaryOperation %}
    | MD _  "&"  _ XOR      {% processBinaryOperation %}
    | MD _  "∧"  _ XOR      {% processBinaryOperation %}
    | MD _  "."  _ XOR      {% processBinaryOperation %}
    | XOR                   {% id %}

# XOR
XOR -> XOR _ "XOR" _ P      {% processBinaryOperation %}
     | XOR _ "xor" _ P      {% processBinaryOperation %}
     | XOR _  "^"  _ P      {% processBinaryOperation %}
     | XOR _  "⊻"  _ P      {% processBinaryOperation %}
     | P                    {% id %}

# Parentheses
P -> "(" _ AS _ ")"         {% processBrackets %}
   | N                      {% id %}

# NOT
N -> "NOT" _ P              {% processNot %}
   | "not" _ P              {% processNot %}
   |  "!"  _ P              {% processNot %}
   |  "~"  _ P              {% processNot %}
   |  "¬"  _ P              {% processNot %}
   | L                      {% id %}

# Literals are literal true and false plus (single capital) letters
L -> "true"           {% (d) => ({ type: 'LogicLiteral', properties: { value: true }, children: {} }) %}
   | "True"           {% (d) => ({ type: 'LogicLiteral', properties: { value: true }, children: {} }) %}
   | "T"              {% (d) => ({ type: 'LogicLiteral', properties: { value: true }, children: {} }) %}
   | "1"              {% (d) => ({ type: 'LogicLiteral', properties: { value: true }, children: {} }) %}
   | "false"          {% (d) => ({ type: 'LogicLiteral', properties: { value: false }, children: {} }) %}
   | "False"          {% (d) => ({ type: 'LogicLiteral', properties: { value: false }, children: {} }) %}
   | "F"              {% (d) => ({ type: 'LogicLiteral', properties: { value: false }, children: {} }) %}
   | "0"              {% (d) => ({ type: 'LogicLiteral', properties: { value: false }, children: {} }) %}
   | [A-EG-SU-Z]	  {% (d) => ({ type: 'Symbol', properties: { letter: d[0] }, children: {} }) %}

# Whitespace. The important thing here is that the postprocessor
# is a null-returning function. This is a memory efficiency trick.
_ -> [\s]:*     {% function(d) {return null } %}
