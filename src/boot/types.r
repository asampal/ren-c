REBOL [
	System: "REBOL [R3] Language Interpreter and Run-time Environment"
	Title: "Datatype definitions"
	Rights: {
		Copyright 2012 REBOL Technologies
		REBOL is a trademark of REBOL Technologies
	}
	License: {
		Licensed under the Apache License, Version 2.0
		See: http://www.apache.org/licenses/LICENSE-2.0
	}
	Purpose: {
		These words define the REBOL datatypes and their related attributes.
		This table generates a variety of C defines and intialization tables.
		During build, when this file is processed, this section is changed to
		hold just the datatype words - the initial entries the word table.

		name		- name of datatype (generates words)
		class		- how type actions are dispatched (T_type)
		mold		- mold format: - self, + type, * typeclass
		form		- form format: above, and f* for special form functions
		path		- it supports various path forms (* for same as typeclass)
		make		- It can be made with #[datatype] method
		typesets	- what typesets the type belongs to

		If the (CLASS) is in a paren that means it has evaluator behavior,
		vs. being passed through as-is.  (e.g. a lit-word is "evaluative")
	}
]


[name		class		mold	form	path	make	typesets]

trash		0			-		-		-		-		-
end         0           -		-       -		-		-
unset       none        -		-       -		*		-

;-- Scalars

none        none        +		+       -		*		-
logic       logic       *		*       -		*		-
integer     integer     *		*       -		-		[number scalar]
decimal     decimal     *		*       -		*		[number scalar]
percent     decimal     *		*       -		*		[number scalar]
money       money       *		*       -		-		scalar
char        char        *		f*      -		-		scalar
pair        pair        *		*       *		*		scalar
tuple       tuple       *		*       *		*		scalar
time        time        *		*       *		*		scalar
date        date        *		*       *		*		-

;-- Series

binary      string      +		+       *		*		[series]
string      string      +		f*      *		*		[series string]
file        string      +		f*      file	*		[series string]
email       string      +		f*      *		*		[series string]
url         string      +		f*      file	*		[series string]
tag         string      +		+       *		*		[series string]

bitset      bitset      *		*       *		*		-
image       image       +		+       *		*		[series]
vector      vector      -		-       *		*		[series]

block       array       *		f*      *		*		[series array]
paren       (array)      *		f*      *		*		[series array]

path        (array)     *		*       *		*		[series path array]
set-path    (array)     *		*       *		*		[series path array]
get-path    (array)     *		*       *		*		[series path array]
lit-path    (array)     *		*       *		*		[series path array]

map         map         +		f*      *		*		-

datatype    datatype    +		f*      -		*		-
typeset     typeset     +		f*      -		*		-

;-- Order dependent: next few words

word        (word)      +        *       -      -		word
set-word    (word)      +        *       -      -		word
get-word    (word)      +        *       -      -		word
lit-word    (word)      +        *       -      -		word
refinement  word        +        *       -      -		word
issue       word        +        *       -      -		word

native      (function)  *        -       -      *		function
action      (function)  *        -       -      *		function
routine     (routine)   *        -       -      *		function
command     (function)  -        -       -      *		function
closure     (function)  *        -       -      *		function
function    (function)  *        -       -      *		function

;-- we make FRAME! evaluative so the evaluator can see it to crash on it...
frame       (frame)     -        -       *      -		-

object      object      *        f*      *      *		object
module      object      *        f*      *      *		object
error       object      +        f+      *      *		object
task        object      +        +       *      *		object
port        port        object   object  object -		object

gob         gob         *        *       *      *		-
event       event       *        *       *      *		-
callback    callback    -        -       -      -		-
handle      0           -        -       -      -		-
struct      struct      *        *       *      *		-
library     library     -        -       -      -		-
