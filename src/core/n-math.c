/***********************************************************************
**
**  REBOL [R3] Language Interpreter and Run-time Environment
**
**  Copyright 2012 REBOL Technologies
**  REBOL is a trademark of REBOL Technologies
**
**  Licensed under the Apache License, Version 2.0 (the "License");
**  you may not use this file except in compliance with the License.
**  You may obtain a copy of the License at
**
**  http://www.apache.org/licenses/LICENSE-2.0
**
**  Unless required by applicable law or agreed to in writing, software
**  distributed under the License is distributed on an "AS IS" BASIS,
**  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
**  See the License for the specific language governing permissions and
**  limitations under the License.
**
************************************************************************
**
**  Module:  n-math.c
**  Summary: native functions for math
**  Section: natives
**  Author:  Carl Sassenrath
**  Notes:   See also: the numeric datatypes
**
***********************************************************************/

#include "sys-core.h"
#include "tmp-comptypes.h"
#include "sys-deci-funcs.h"

#include <math.h>
#include <float.h>

#define	LOG2	0.6931471805599453
#define	EPS		2.718281828459045235360287471

extern const double pi1;
const double pi1 = 3.14159265358979323846;
const double pi2 = 2.0 * 3.14159265358979323846;

#ifndef DBL_EPSILON
#define DBL_EPSILON	2.2204460492503131E-16
#endif

#define	AS_DECIMAL(n) (IS_INTEGER(n) ? (REBDEC)VAL_INT64(n) : VAL_DECIMAL(n))

enum {SINE, COSINE, TANGENT};


/***********************************************************************
**
*/	static REBDEC Trig_Value(const REBVAL *value, REBOOL degrees, REBCNT which)
/*
**	Convert integer arg, if present, to decimal and convert to radians
**	if necessary.  Clip ranges for correct REBOL behavior.
**
***********************************************************************/
{
	REBDEC dval = AS_DECIMAL(value);

	if (degrees) {
        /* get dval between -360.0 and 360.0 */
        dval = fmod (dval, 360.0);

        /* get dval between -180.0 and 180.0 */
        if (fabs (dval) > 180.0) dval += dval < 0.0 ? 360.0 : -360.0;
        if (which == TANGENT) {
            /* get dval between -90.0 and 90.0 */
            if (fabs (dval) > 90.0) dval += dval < 0.0 ? 180.0 : -180.0;
        } else if (which == SINE) {
            /* get dval between -90.0 and 90.0 */
            if (fabs (dval) > 90.0) dval = (dval < 0.0 ? -180.0 : 180.0) - dval;
        }
        dval = dval * pi1 / 180.0; // to radians
    }

	return dval;
}


/***********************************************************************
**
*/	static void Arc_Trans(REBVAL *out, const REBVAL *value, REBOOL degrees, REBCNT kind)
/*
***********************************************************************/
{
	REBDEC dval = AS_DECIMAL(value);
	if (kind != TANGENT && (dval < -1 || dval > 1)) raise Error_0(RE_OVERFLOW);

	if (kind == SINE) dval = asin(dval);
	else if (kind == COSINE) dval = acos(dval);
	else dval = atan(dval);

	if (degrees) dval = dval * 180.0 / pi1; // to degrees

	SET_DECIMAL(out, dval);
}


/***********************************************************************
**
*/	REBNATIVE(cosine)
/*
***********************************************************************/
{
	REBDEC dval = cos(Trig_Value(D_ARG(1), !D_REF(2), COSINE));
	if (fabs(dval) < DBL_EPSILON) dval = 0.0;
	SET_DECIMAL(D_OUT, dval);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(sine)
/*
***********************************************************************/
{
	REBDEC dval = sin(Trig_Value(D_ARG(1), !D_REF(2), SINE));
	if (fabs(dval) < DBL_EPSILON) dval = 0.0;
	SET_DECIMAL(D_OUT, dval);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(tangent)
/*
***********************************************************************/
{
	REBDEC dval = Trig_Value(D_ARG(1), !D_REF(2), TANGENT);
	if (Eq_Decimal(fabs(dval), pi1 / 2.0)) raise Error_0(RE_OVERFLOW);
	SET_DECIMAL(D_OUT, tan(dval));
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(arccosine)
/*
***********************************************************************/
{
	Arc_Trans(D_OUT, D_ARG(1), !D_REF(2), COSINE);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(arcsine)
/*
***********************************************************************/
{
	Arc_Trans(D_OUT, D_ARG(1), !D_REF(2), SINE);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(arctangent)
/*
***********************************************************************/
{
	Arc_Trans(D_OUT, D_ARG(1), !D_REF(2), TANGENT);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(exp)
/*
***********************************************************************/
{
	REBDEC	dval = AS_DECIMAL(D_ARG(1));
	static REBDEC eps = EPS;

	dval = pow(eps, dval);
//!!!!	Check_Overflow(dval);
	SET_DECIMAL(D_OUT, dval);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(log_10)
/*
***********************************************************************/
{
	REBDEC dval = AS_DECIMAL(D_ARG(1));
	if (dval <= 0) raise Error_0(RE_POSITIVE);
	SET_DECIMAL(D_OUT, log10(dval));
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(log_2)
/*
***********************************************************************/
{
	REBDEC dval = AS_DECIMAL(D_ARG(1));
	if (dval <= 0) raise Error_0(RE_POSITIVE);
	SET_DECIMAL(D_OUT, log(dval) / LOG2);
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(log_e)
/*
***********************************************************************/
{
	REBDEC dval = AS_DECIMAL(D_ARG(1));
	if (dval <= 0) raise Error_0(RE_POSITIVE);
	SET_DECIMAL(D_OUT, log(dval));
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(square_root)
/*
***********************************************************************/
{
	REBDEC dval = AS_DECIMAL(D_ARG(1));
	if (dval < 0) raise Error_0(RE_POSITIVE);
	SET_DECIMAL(D_OUT, sqrt(dval));
	return R_OUT;
}


/***********************************************************************
**
*/	REBNATIVE(shift)
/*
**		shift int bits arithmetic or logical
**
***********************************************************************/
{
	REBI64 b = VAL_INT64(D_ARG(2));
	REBVAL *a = D_ARG(1);
	REBU64 c, d;

	if (b < 0) {
		// this is defined:
		c = -(REBU64)b;
		if (c >= 64) {
			if (D_REF(3)) VAL_INT64(a) = 0;
			else VAL_INT64(a) >>= 63;
		} else {
			if (D_REF(3)) VAL_UNT64(a) >>= c;
			else VAL_INT64(a) >>= (REBI64)c;
		}
	} else {
		if (b >= 64) {
			if (D_REF(3)) VAL_INT64(a) = 0;
			else if (VAL_INT64(a)) raise Error_0(RE_OVERFLOW);
		} else
			if (D_REF(3)) VAL_UNT64(a) <<= b;
			else {
				c = (REBU64)MIN_I64 >> b;
				d = VAL_INT64(a) < 0 ? -VAL_UNT64(a) : VAL_UNT64(a);
				if (c <= d) {
					if ((c < d) || (VAL_INT64(a) >= 0))
						raise Error_0(RE_OVERFLOW);

					VAL_INT64(a) = MIN_I64;
				}
				else
					VAL_INT64(a) <<= b;
			}
	}
	return R_ARG1;
}


/***********************************************************************
**
*/	REBINT Compare_Modify_Values(REBVAL *a, REBVAL *b, REBINT strictness)
/*
**		Compare 2 values depending on level of strictness.  It leans
**		upon the per-type comparison functions (that have a more typical
**		interface of returning [1, 0, -1] and taking a CASE parameter)
**		but adds a layer of being able to check for specific types
**		of equality...which those comparison functions do not discern.
**
**		Strictness:
**			0 - coersed equality
**			1 - equivalence
**			2 - strict equality
**			3 - same (identical bits)
**
**		   -1 - greater or equal
**		   -2 - greater
**
**		!!! This routine (may) modify the value cells for 'a' and 'b' in
**		order to coerce them for easier comparison.  Most usages are
**		in native code that can overwrite its argument values without
**		that being a problem, so it doesn't matter.
**
***********************************************************************/
{
	REBCNT ta = VAL_TYPE(a);
	REBCNT tb = VAL_TYPE(b);
	REBCTF code;
	REBINT result;

	if (ta != tb) {
		if (strictness > 1) return FALSE;

		switch (ta) {
		case REB_INTEGER:
			if (tb == REB_DECIMAL || tb == REB_PERCENT) {
				SET_DECIMAL(a, (REBDEC)VAL_INT64(a));
				goto compare;
			}
			else if (tb == REB_MONEY) {
				SET_MONEY_AMOUNT(a, int_to_deci(VAL_INT64(a)));
				goto compare;
			}
			break;

		case REB_DECIMAL:
		case REB_PERCENT:
			if (tb == REB_INTEGER) {
				SET_DECIMAL(b, (REBDEC)VAL_INT64(b));
				goto compare;
			}
			else if (tb == REB_MONEY) {
				SET_MONEY_AMOUNT(a, decimal_to_deci(VAL_DECIMAL(a)));
				goto compare;
			}
			else if (tb == REB_DECIMAL || tb == REB_PERCENT) // equivalent types
				goto compare;
			break;

		case REB_MONEY:
			if (tb == REB_INTEGER) {
				SET_MONEY_AMOUNT(b, int_to_deci(VAL_INT64(b)));
				goto compare;
			}
			if (tb == REB_DECIMAL || tb == REB_PERCENT) {
				SET_MONEY_AMOUNT(b, decimal_to_deci(VAL_DECIMAL(b)));
				goto compare;
			}
			break;

		case REB_WORD:
		case REB_SET_WORD:
		case REB_GET_WORD:
		case REB_LIT_WORD:
		case REB_REFINEMENT:
		case REB_ISSUE:
			if (ANY_WORD(b)) goto compare;
			break;

		case REB_STRING:
		case REB_FILE:
		case REB_EMAIL:
		case REB_URL:
		case REB_TAG:
			if (ANY_STR(b)) goto compare;
			break;
		}

		if (strictness == 0 || strictness == 1) return FALSE;
		//if (strictness >= 2)
		raise Error_2(RE_INVALID_COMPARE, Type_Of(a), Type_Of(b));
	}

compare:
	// At this point, both args are of the same datatype.
	if (!(code = Compare_Types[VAL_TYPE(a)])) return FALSE;
	result = code(a, b, strictness);
	if (result < 0) raise Error_2(RE_INVALID_COMPARE, Type_Of(a), Type_Of(b));
	return result;
}


//	EQUAL? < EQUIV? < STRICT-EQUAL? < SAME?

/***********************************************************************
**
*/	REBNATIVE(equalq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 0)) return R_TRUE;
	return R_FALSE;
}

/***********************************************************************
**
*/	REBNATIVE(not_equalq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 0)) return R_FALSE;
	return R_TRUE;
}

/***********************************************************************
**
*/	REBNATIVE(equivq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 1)) return R_TRUE;
	return R_FALSE;
}

/***********************************************************************
**
*/	REBNATIVE(not_equivq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 1)) return R_FALSE;
	return R_TRUE;
}

/***********************************************************************
**
*/	REBNATIVE(strict_equalq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 2)) return R_TRUE;
	return R_FALSE;
}

/***********************************************************************
**
*/	REBNATIVE(strict_not_equalq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 2)) return R_FALSE;
	return R_TRUE;
}

/***********************************************************************
**
*/	REBNATIVE(sameq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), 3)) return R_TRUE;
	return R_FALSE;
}

/***********************************************************************
**
*/	REBNATIVE(lesserq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), -1)) return R_FALSE;
	return R_TRUE;
}

/***********************************************************************
**
*/	REBNATIVE(lesser_or_equalq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), -2)) return R_FALSE;
	return R_TRUE;
}

/***********************************************************************
**
*/	REBNATIVE(greaterq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), -2)) return R_TRUE;
	return R_FALSE;
}

/***********************************************************************
**
*/	REBNATIVE(greater_or_equalq)
/*
***********************************************************************/
{
	if (Compare_Modify_Values(D_ARG(1), D_ARG(2), -1)) return R_TRUE;
	return R_FALSE;
}

/***********************************************************************
**
*/	REBNATIVE(maximum)
/*
***********************************************************************/
{
	REBVAL a, b;

	if (IS_PAIR(D_ARG(1)) || IS_PAIR(D_ARG(2))) {
		Min_Max_Pair(D_OUT, D_ARG(1), D_ARG(2), 1);
		return R_OUT;
	}

	a = *D_ARG(1);
	b = *D_ARG(2);
	if (Compare_Modify_Values(&a, &b, -1)) return R_ARG1;
	return R_ARG2;
}

/***********************************************************************
**
*/	REBNATIVE(minimum)
/*
***********************************************************************/
{
	REBVAL a, b;

	if (IS_PAIR(D_ARG(1)) || IS_PAIR(D_ARG(2))) {
		Min_Max_Pair(D_OUT, D_ARG(1), D_ARG(2), 0);
		return R_OUT;
	}

	a = *D_ARG(1);
	b = *D_ARG(2);
	if (Compare_Modify_Values(&a, &b, -1)) return R_ARG2;
	return R_ARG1;
}


/***********************************************************************
**
*/	REBNATIVE(negativeq)
/*
***********************************************************************/
{
	REBVAL zero;
	VAL_SET_ZEROED(&zero, VAL_TYPE(D_ARG(1)));

	if (Compare_Modify_Values(D_ARG(1), &zero, -1)) return R_FALSE;
	return R_TRUE;
}


/***********************************************************************
**
*/	REBNATIVE(positiveq)
/*
***********************************************************************/
{
	REBVAL zero;
	VAL_SET_ZEROED(&zero, VAL_TYPE(D_ARG(1)));

	if (Compare_Modify_Values(D_ARG(1), &zero, -2)) return R_TRUE;

	return R_FALSE;
}


/***********************************************************************
**
*/	REBNATIVE(zeroq)
/*
***********************************************************************/
{
	REBCNT type = VAL_TYPE(D_ARG(1));

	if (type >= REB_INTEGER && type <= REB_TIME) {
		REBVAL zero;
		VAL_SET_ZEROED(&zero, type);

		if (Compare_Modify_Values(D_ARG(1), &zero, 1)) return R_TRUE;
	}
	return R_FALSE;
}
