extends Node
class_name SubarrayUtils # This registers the class globally.

## KMP (Knuth-Morris-Pratt) algorithm for substring search in arrays.
static func is_contiguous_subarray(big_array: Array, sub_array: Array) -> bool:
	# Decide what to do with empty sub_array: here we assume an empty array is a match.
	if sub_array.size() == 0:
		return true
	# Compute the LPS (Longest Prefix Suffix) table for the sub_array.
	var lps = _compute_lps(sub_array)
	
	var i = 0 # index for big_array
	var j = 0 # index for sub_array (pattern)
	
	while i < big_array.size():
		if big_array[i] == sub_array[j]:
			i += 1
			j += 1
			# If we've reached the end of the sub_array, we found a complete match.
			if j == sub_array.size():
				return true
		else:
			# If there was a partial match, fall back using the lps table.
			if j != 0:
				j = lps[j - 1]
			else:
				i += 1
				
	return false


# Helper function to compute the LPS (Longest Prefix Suffix) table for the pattern.
static func _compute_lps(pattern: Array) -> Array:
	var lps = []
	lps.resize(pattern.size())
	lps[0] = 0 # lps[0] is always 0
	var length = 0 # length of the previous longest prefix suffix
	var i = 1

	while i < pattern.size():
		if pattern[i] == pattern[length]:
			length += 1
			lps[i] = length
			i += 1
		else:
			if length != 0:
				length = lps[length - 1]
			else:
				lps[i] = 0
				i += 1
				
	return lps