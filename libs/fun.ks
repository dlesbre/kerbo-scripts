// Copyright (C) 2026 Dorian Lesbre
// This program is licensed under the GNU General Public License v3.0.
// See <https://www.gnu.org/licenses/gpl-3.0.html> for details.

// libs/fun.ks - functional programming iterators and combinators
// =============================================================================

function identity { parameter x. return x. }

// list_filter(f, l) is the sublist of elements of l that verify f
function list_filter {
  parameter filter. // : 'a -> Boolean
  parameter lst. // : List<'a>
  local res is list().
  for elt in lst {
    if filter(elt) { res:add(elt). }
  }
  return res.
}

// list_sum(f, [x1, ..., xn]) is f(x1) + ... + f(xn)
function list_sum {
  parameter get_value. // : 'a -> Scalar<"b>
  parameter lst. // : List<'a>
  local sum is 0.
  for x in lst { set sum to sum + get_value(x). }
  return sum.
}
