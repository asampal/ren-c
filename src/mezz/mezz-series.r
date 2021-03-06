REBOL [
	System: "REBOL [R3] Language Interpreter and Run-time Environment"
	Title: "REBOL 3 Mezzanine: Series Helpers"
	Rights: {
		Copyright 2012 REBOL Technologies
		REBOL is a trademark of REBOL Technologies
	}
	License: {
		Licensed under the Apache License, Version 2.0
		See: http://www.apache.org/licenses/LICENSE-2.0
	}
]

empty?: func [
	{Returns TRUE if empty or NONE, or for series if index is at or beyond its tail.}
	series [any-series! object! gob! port! bitset! map! none!]
][
	tail? series
]

offset-of: func [
	"Returns the offset between two series positions."
	series1 [any-series!]
	series2 [any-series!]
][
	subtract index-of series2 index-of series1
]

found?: func [
	"Returns TRUE if value is not NONE."
	value
][
	not none? :value
]

last?: single?: func [
	"Returns TRUE if the series length is 1."
	series [any-series! port! map! tuple! bitset! object! gob! any-word!]
][
	1 = length series
]

extend: func [
	"Extend an object, map, or block type with word and value pair."
	obj [object! map! block! paren!] {object to extend (modified)}
	word [any-word!]
	val
][
	if :val [append obj reduce [to-set-word word :val]]
	:val
]

rejoin: func [
	"Reduces and joins a block of values."
	block [block!] "Values to reduce and join"
	;/with "separator"
][
	if empty? block: reduce block [return block]
	append either any-series? first block [copy first block][
		form first block
	] next block
]

remold: func [
	{Reduces and converts a value to a REBOL-readable string.}
	value {The value to reduce and mold}
	/only {For a block value, mold only its contents, no outer []}
	/all  {Mold in serialized format}
	/flat {No indentation}
][
	mold/:only/:all/:flat reduce :value
]

charset: func [
	"Makes a bitset of chars for the parse function."
	chars [string! block! binary! char! integer!]
	/length "Preallocate this many bits"
	len [integer!] "Must be > 0"
	/local charset-length length-of
][
	;-- CHARSET function historically has a refinement called /LENGTH, that
	;-- is used to preallocate bits.  Yet the LENGTH? function has been
	;-- changed to use just the word LENGTH.  We could change this to
	;-- /CAPACITY SIZE or something similar, but keep it working for now.
	;--
	charset-length: length		; refinement passed in
	length-of: :lib/length		; traditional LENGTH function
	unset 'length				; helps avoid overlooking the ambiguity

	either charset-length [append make bitset! len chars] [make bitset! chars]
]

array: func [
	"Makes and initializes a series of a given size."
	size [integer! block!] "Size or block of sizes for each dimension"
	/initial "Specify an initial value for all elements"
	value "Initial value (will be called each time if a function)"
	/local block rest
][
	if block? size [
		if tail? rest: next size [rest: none]
		unless integer? set/any 'size first size [
			cause-error 'script 'expect-arg reduce ['array 'size type-of :size]
		]
	]
	block: make block! size
	case [
		block? :rest [
			loop size [block: insert/only block array/initial rest :value]
		]
		any-series? :value [
			loop size [block: insert/only block copy/deep value]
		]
		any-function? :value [ ; So value can be a thunk :)
			loop size [block: insert/only block value] ; Called every time
		]
		true [
			insert/dup block value size
		]
	]
	head block
]

replace: func [
	"Replaces a search value with the replace value within the target series."
	target  [any-series!] "Series to replace within (modified)"
	pattern "Value to be replaced (converted if necessary)"
	replacement "Value to replace with (called each time if a function)"

	; !!! Note these refinments alias ALL, CASE, TAIL natives!
	/all "Replace all occurrences"
	/case "Case-sensitive replacement"
	/tail "Return target after the last replacement position"

	/local save-target len value pos do-break

	; Consider adding an /any refinement to use find/any, once that works.
][
	save-target: target

	; !!! These conversions being missing seems a problem with FIND the native
	; as a holdover from pre-open-source Rebol when mezzanine development
	; had no access to source (?).  Correct answer is likely to fix FIND:
	;
	;    >> find "abcdef" <cde>
	;    >> == "cdef" ; should probably be NONE!
	;
	;    >> find "ab<cde>f" <cde>
	;    == "cde>f" ; should be "<cde>f"
	;
	; Note that if a FORM actually happens inside of FIND, it could wind up
	; happening repeatedly in the /ALL case if that happens.

	len: lib/case [
		; leave bitset patterns as-is regardless of target type, len = 1
		bitset? :pattern 1

		any-string? target [
			unless string? :pattern [pattern: form :pattern]
			length :pattern
		]

		binary? target [
			; Target is binary, pattern is not, make pattern a binary
			unless binary? :pattern [pattern: to-binary :pattern]
			length :pattern
		]

		any-block? :pattern [length :pattern]

		true 1
	]

	while [pos: find/:case target :pattern] [
		; apply replacement if function, or drops pos if not
		; the parens quarantine function invocation to maximum arity of 1
		(value: replacement pos)

		target: change/part pos :value len

		unless all [break] ;-- tests /ALL refinement, not ALL native
	]

	either tail [target] [save-target]
]

reword: func [
	"Make a string or binary based on a template and substitution values."
	source [any-string! binary!] "Template series with escape sequences"
	values [map! object! block!] "Keyword literals and value expressions"
	/case "Characters are case-sensitive"  ;!!! Note CASE is redefined in here!
	/only "Use values as-is, do not reduce the block, insert block values"
	/escape "Choose your own escape char(s) or [begin end] delimiters"
	char [char! any-string! binary! block! none!] {Default "$"}
	/into "Insert into a buffer instead (returns position after insert)"
	output [any-string! binary!] "The buffer series (modified)"
	/local char-end vals word wtype cword out fout rule a b w v c
][
	assert/type [local none!]  ; Prevent locals injection
	unless into [output: make source length source]
	; Determine the datatype to convert the keywords to internally
	; Case-sensitive map keys must be binary, tags are special-cased by parse
	wtype: lib/case [case binary! tag? source string! 'else type-of source]
	; Determine the escape delimiter(s), if any
	lib/case/all [
		not escape [char: "$"]
		block? char [
			; Have to use parse here because ASSERT/type is broken
			rule: [char! | any-string! | binary!]
			unless parse c: char [set char rule set char-end opt rule] [
				cause-error 'script 'invalid-arg reduce [c]
			]
		]
		char? char [char: to wtype char]
		char? char-end [char-end: to wtype char-end]
	]
	lib/case [
		; Check whether values is a map of the kind we can use internally
		all [
			map? values      ; Must be a map to use series keys with no dups
			empty? char-end  ; If we have char-end, it gets appended to the keys
			for-each [w v] values [
				; Key types must match wtype and no unset values allowed
				if any [unset? :v wtype <> type-of :w] [break/return false]
				true
			]
		] [vals: values]  ; Success, so use it
		; Otherwise, convert keywords to wtype and eliminate duplicates and empties
		; Last duplicate keyword wins; empty keywords, unset or none vals removed
		; Any trailing delimiter is added to the end of the key for convenience
		all [
			vals: make map! length values  ; Make a new map internally
			not only block? values  ; Should we evaluate value expressions?
		] [
			while [not tail? values] [
				w: first+ values  ; Keywords are not evaluated
				set/any 'v do/next values 'values
				if any [set-word? :w lit-word? :w] [w: to word! :w]
				lib/case [
					wtype = type-of :w none
					wtype <> binary! [w: to wtype :w]
					any-string? :w [w: to binary! :w]
					'else [w: to binary! to string! :w]
				]
				unless empty? w [
					unless empty? char-end [w: append copy w char-end]
					poke vals w unless unset? :v [:v]
				]
			]
		]
		'else [  ; /only doesn't apply, just assign raw values
			for-each [w v] values [  ; for-each can be used on all values types
				if any [set-word? :w lit-word? :w] [w: to word! :w]
				lib/case [
					wtype = type-of :w none
					wtype <> binary! [w: to wtype :w]
					any-string? :w [w: to binary! :w]
					'else [w: to binary! to string! :w]
				]
				unless empty? w [
					unless empty? char-end [w: append copy w char-end]
					poke vals w unless unset? :v [:v]
				]
			]
		]
	]
	; Construct the reword rule
	word: make block! 2 * length vals
	for-each w vals [word: reduce/into [w '|] word]
	word: head remove back word
	; Convert keyword if the type doesn't match
	cword: pick [(w: to wtype w)] wtype <> type-of source
	set/any [out: fout:] pick [
		[   ; Convert to string if type combination needs it
			(output: insert output to string! copy/part a b)
			(output: insert output to string! a)
		][  ; ... otherwise just insert it directly
			(output: insert/part output a b)
			(output: insert output a)
		]
	] or~ tag? source and~ binary? source not binary? output
	escape: [
		copy w word cword out (
			output: insert output lib/case [
				block? v: select vals w [either only [v] :v]
				any-function? :v [apply :v [:b]]
				'else :v
			]
		) a:
	]
	rule: either empty? char [
		; No starting escape string, use TO multi
		[a: any [to word b: [escape | skip]] to end fout]
	][
		; Starting escape string defined, use regular TO
		if wtype <> type-of char [char: to wtype char]
		[a: any [to char b: char [escape | none]] to end fout]
	]
	either case [parse/case source rule] [parse source rule]
	; Return end of output with /into, head otherwise
	either into [output] [head output]
]
; It's big, it's complex, but it works. Placeholder for a native.

move: func [
	"Move a value or span of values in a series."
	source [any-series!] "Source series (modified)"
	offset [integer!] "Offset to move by, or index to move to"
	/part "Move part of a series"
	limit [integer!] "The length of the part to move"
	/skip "Treat the series as records of fixed size" ;; SKIP redefined
	size [integer!] "Size of each record"
	/to "Move to an index relative to the head of the series" ;; TO redefined
][
	unless limit [limit: 1]
	if skip [
		if 1 > size [cause-error 'script 'out-of-range size]
		offset: either to [offset - 1 * size + 1] [offset * size]
		limit: limit * size
	]
	part: take/part source limit
	insert either to [at head source offset] [
		lib/skip source offset
	] part
]

extract: func [
	"Extracts a value from a series at regular intervals."
	series [any-series!]
	width [integer!] "Size of each entry (the skip)"
	/index "Extract from an offset position"
	pos "The position(s)" [any-number! logic! block!]
	/default "Use a default value instead of none"
	value "The value to use (will be called each time if a function)"
	/into "Insert into a buffer instead (returns position after insert)"
	output [any-series!] "The buffer series (modified)"
	/local len val
][  ; Default value is "" for any-string! output
	if zero? width [return any [output make series 0]]  ; To avoid an infinite loop
	len: either positive? width [  ; Length to preallocate
		divide length series width  ; Forward loop, use length
	][
		divide index-of series negate width  ; Backward loop, use position
	]
	unless index [pos: 1]
	either block? pos [
		unless parse pos [some [any-number! | logic!]] [cause-error 'Script 'invalid-arg reduce [pos]]
		if unset? :output [output: make series len * length pos]
		if all [not default any-string? output] [value: copy ""]
		forskip series width [forall pos [
			if none? set/any 'val pick series pos/1 [set/any 'val value]
			output: insert/only output :val
		]]
	][
		if unset? :output [output: make series len]
		if all [not default any-string? output] [value: copy ""]
		forskip series width [
			if none? set/any 'val pick series pos [set/any 'val value]
			output: insert/only output :val
		]
	]
	either into [output] [head output]
]

alter: func [
	"Append value if not found, else remove it; returns true if added."
	series [any-series! port! bitset!] {(modified)}
	value
	/case "Case-sensitive comparison"
][
	if bitset? series [
		return either find series :value [
			remove/part series :value false
		][
			append series :value true
		]
	]
	found? unless remove (
		either case [find/case series :value] [find series :value]
	) [append series :value]
]

collect: func [
	"Evaluates a block, storing values via KEEP function, and returns block of collected values."
	body [block!] "Block to evaluate"
	/into "Insert into a buffer instead (returns position after insert)"
	output [any-series!] "The buffer series (modified)"
][
	; Due to the desire to still be able to use COLLECT in <r3-legacy> mode,
	; the "true valued refinements switch" must be respected.  This is even
	; though the function captures a modality at the time a switch is on,
	; because collect *makes* a function.  :-/

	; This is sad, because @HostileFork considered the ability to add a
	; language feature as powerful as COLLECT to be a compass point driving
	; the repairs and cleanups in Ren/C.  Most of those are invisible, but
	; in this case it cannot be to keep working in legacy mode.
	;
	; But as long as the concern is polluting Ren/C's mezzanine to where it
	; can't be "perfect", the "perfect" version is separated out entirely
	; instead of intermingled.  :-)

	either system/options/refinements-true [
		; Note: because this is a Mezzanine it was loaded with the word valued
		; refinements and unset-unused-refinements, and remembers that...even
		; when the legacy mode is enabled.  Compatibility to not touch code.
		if unset? :output [output: none]

		;; Rebol2, R3-Alpha, Red ;;

		unless output [output: make block! 16]
		do func [keep] body func [
			value [any-type!] /only
		][
			output: apply :insert [output :value none none only]
			:value
		]
		either into [output] [head output]
	][
		;; Ren/C ;;

		output: any [:output make block! 16]
		eval func [<transparent> keep] body func [
			value [any-value!] /only
		][
			output: insert/:only output :value
			:value
		]
		either into [output] [head output]
	]

	; Note that the addition of the <transparent> ties into the successful
	; implementation of definitional return.  Since COLLECT is receiving
	; raw body material from an outside caller, that may have one or more
	; RETURNs in it that have been definitionally bound to their callers.
	; Since FUNC is a generator which makes a local RETURN, it would
	; destroy those bindings unless told not to.  You can choose one way
	; or another, but the right choice here is to leave the bindings as is
	;
	; Note also that removing the ability for DO to evaluate functions in
	; this way is critical to being able to write a wrapper for DO.  If
	; evaluation of this form is allowed to become part of a function,
	; you could never emulate its behavior.  So only one primitive was
	; made that can do this inline evaluation trick: EVAL.
	;
	; As another small point of contrast, ANY-TYPE! is less obvious than
	; ANY-VALUE!...it sounds like it might mean "any DATATYPE! value"
]

format: function [
	"Format a string according to the format dialect."
	rules {A block in the format dialect. E.g. [10 -10 #"-" 4]}
	values
	/pad p
][
	p: any [:p #" "]
	unless block? :rules [rules: reduce [:rules]]
	unless block? :values [values: reduce [:values]]

	; Compute size of output (for better mem usage):
	val: 0
	for-each rule rules [
		if word? :rule [rule: get rule]

		; !!! to-word necessary as long as OPTIONS_DATATYPE_WORD_STRICT exists
		val: val + switch/default to-word type-of :rule [
			integer! [abs rule]
			string! [length rule]
			char!    [1]
		][0]
	]

	out: make string! val
	insert/dup out p val

	; Process each rule:
	for-each rule rules [
		if word? :rule [rule: get rule]

		; !!! to-word necessary as long as OPTIONS_DATATYPE_WORD_STRICT exists
		switch to-word type-of :rule [
			integer! [
				pad: rule
				val: form first+ values
				clear at val 1 + abs rule
				if negative? rule [
					pad: rule + length val
					if negative? pad [out: skip out negate pad]
					pad: length val
				]
				change out :val
				out: skip out pad ; spacing (remainder)
			]
			string!  [out: change out rule]
			char!    [out: change out rule]
		]
	]

	; Provided enough rules? If not, append rest:
	if not tail? values [append out values]
	head out
]

printf: func [
	"Formatted print."
	fmt "Format"
	val "Value or block of values"
][
	print format :fmt :val
]

split: func [
	"Split a series into pieces; fixed or variable size, fixed number, or at delimiters"
	series	[any-series!] "The series to split"
	dlm		[block! integer! char! bitset! any-string!] "Split size, delimiter(s), or rule(s)."
	/into	"If dlm is an integer, split into n pieces, rather than pieces of length n."
	/local size piece-size count mk1 mk2 res fill-val add-fill-val
][
	either all [block? dlm  parse dlm [some integer!]] [
		map-each len dlm [
			either positive? len [
				copy/part series series: skip series len
			] [
				series: skip series negate len
				; return unset so that nothing is added to output
				()
			]
		]
	][
		size: dlm   ; alias for readability
		res: collect [
			parse series case [
				all [integer? size  into] [
					if size < 1 [cause-error 'Script 'invalid-arg size]
					count: size - 1
					piece-size: to integer! round/down divide length series size
					if zero? piece-size [piece-size: 1]
					[
						count [copy series piece-size skip (keep/only series)]
						copy series to end (keep/only series)
					]
				]
				integer? dlm [
					if size < 1 [cause-error 'Script 'invalid-arg size]
					[any [copy series 1 size skip (keep/only series)]]
				]
				'else [ ; = any [bitset? dlm  any-string? dlm  char? dlm]
					[any [mk1: some [mk2: dlm break | skip] (keep/only copy/part mk1 mk2)]]
				]
			]
		]
		;-- Special processing, to handle cases where the spec'd more items in
		;   /into than the series contains (so we want to append empty items),
		;   or where the dlm was a char/string/charset and it was the last char
		;   (so we want to append an empty field that the above rule misses).
		fill-val: does [copy either any-block? series [[]] [""]]
		add-fill-val: does [append/only res fill-val]
		case [
			all [integer? size  into] [
				; If the result is too short, i.e., less items than 'size, add
				; empty items to fill it to 'size.
				; We loop here, because insert/dup doesn't copy the value inserted.
				if size > length res [
					loop (size - length res) [add-fill-val]
				]
			]
			; integer? dlm [
			; ]
			'else [ ; = any [bitset? dlm  any-string? dlm  char? dlm]
				; If the last thing in the series is a delimiter, there is an
				; implied empty field after it, which we add here.
				case [
					bitset? dlm [
						; ATTEMPT is here because LAST will return NONE for an
						; empty series, and finding none in a bitest is not allowed.
						if attempt [find dlm last series] [add-fill-val]
					]
					char? dlm [
						if dlm = last series [add-fill-val]
					]
					string? dlm [
						if all [
							find series dlm
							empty? find/last/tail series dlm
						] [add-fill-val]
					]
				]
			]
		]

		res
	]
]

find-all: function [
	"Find all occurrences of a value within a series (allows modification)."
	'series [word!] "Variable for block, string, or other series"
	value
	body [block!] "Evaluated for each occurrence"
][
	assert [any-series? orig: get series]
	while [any [set series find get series :value (set series orig false)]] [
		do body
		++ (series)
	]
]
