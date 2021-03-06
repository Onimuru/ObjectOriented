#Requires AutoHotkey v2.0-beta

/*
* MIT License
*
* Copyright (c) 2022 Onimuru
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

;============ Auto-Execute ====================================================;

PatchArrayPrototype()

;============== Function ======================================================;

Print(input) {
	if (input is Array) {
		if (length := input.Length) {
			string := "["

			for value in input {
				if (!IsSet(value)) {
					value := ""
				}

				string .= ((IsObject(value)) ? (Print(value)) : ((IsNumber(value)) ? (RegExReplace(value, "S)^0+(?=\d\.?)|(?=\.).*?\K\.?0*$")) : (Format('"{}"', value)))) . ((A_Index < length) ? (", ") : ("]"))
			}
		}
		else {
			string := "[]"
		}
	}
	else if (input is Object) {
		if (count := ObjOwnPropCount(input)) {
			string := "{"

			for key, value in (input.OwnProps()) {
				string .= key . ": " . ((IsObject(value)) ? (Print(value)) : ((IsNumber(value)) ? (RegExReplace(value, "S)^0+(?=\d\.?)|(?=\.).*?\K\.?0*$")) : (Format('"{}"', value)))) . ((A_Index < count) ? (", ") : ("}"))
			}
		}
		else {
			string := "{}"
		}
	}
	else {
		string := input
	}

	return (string)
}

;* Range(start[, stop, step])
;* Description:
	;* Returns a sequence of integers starting at `start` with increments of `step`, ending at `stop` (noninclusive).  ;: https://pynative.com/python-range-function/
Range(start, stop := "", step := 1) {
	if (stop == "") {
		stop := start, start := 0
	}

	if (!(IsInteger(start) && IsInteger(stop))) {
		throw (TypeError("TypeError.", -1, Format("Range({}) may only contain integers.", [start, stop, step].Join(", "))))
	}

	loop (r := [], Max(Ceil((stop - start)/step), 0)) {
		r.Push(start), start += step
	}

	return (r)
}

PatchArrayPrototype() {

	;----------------??? AHK ???--------------------------------------------------------;
	;------------------------------------------------------- __Item ---------------;

	Default__Item_Get := Array.Prototype.GetOwnPropDesc("__Item").Get, Default__Item_Set := Array.Prototype.GetOwnPropDesc("__Item").Set  ;* Store the defualt implementation in a variable. This is done so that a reference can be retained even if the defualt implementation is deleted/overritten.

	Array.Prototype.DefineProp("__Item", {Get: Custom__Item_Get, Set: Custom__Item_Set})  ;* Override the default implementation with a custom version.

	Custom__Item_Get(this, zeroIndex) {
		try {
			return (Default__Item_Get(this, zeroIndex + (zeroIndex >= 0)))  ;* Delegate to the default implementation.
		}
		catch (IndexError as e) {
			throw (IndexError(e.Message, -2, zeroIndex))  ;* This is here to report a zero-based index in `e.Extra`.
		}
		catch (TypeError as e) {  ;* This error is triggered when you try to index with strings for example array["string"].
			throw (TypeError(e.Message, -2, e.Extra))  ;* This is here to point `e.What` to the actual origin of the error.
		}
	}

	Custom__Item_Set(this, value, zeroIndex) {
		try {
			return (Default__Item_Set(this, value, zeroIndex + (zeroIndex >= 0)))
		}
		catch (IndexError as e) {
			throw (IndexError(e.Message, -2, zeroIndex))  ;~ When assigning or retrieving an array element, the absolute value of the index must be between 0 and the Length of the array, otherwise an exception is thrown. An array can be resized by inserting or removing elements with the appropriate method, or by assigning Length.
		}
		catch (TypeError as e) {
			throw (TypeError(e.Message, -2, e.Extra))
		}
	}

	;------------------------------------------------------- __Enum ---------------;

	Default__Enum_Call := Array.Prototype.GetOwnPropDesc("__Enum").Call

	Array.Prototype.DefineProp("__Enum", {Call: Custom__Enum_Call})  ;* Override the default dispatcher with a custom version.

	Custom__Enum_Call(this, numberOfVars) {
		DefaultEnum := Default__Enum_Call(this, numberOfVars)  ;* Have the default dispatcher provide the original one based enumerator implementation.

		switch (numberOfVars) {
			case 1:
				return (DefaultEnum)  ;* `for v in array`, no special handling needed since it enumerates the values only.
			case 2:
				return (CustomEnum) ;* `for i, v in array`.

				CustomEnum(&zeroIndex, &value) {
					if (DefaultEnum(&oneIndex, &value)) {  ;* While the array has Items, retrieve one with `oneIndex` and assign Item to the for-loop's second value.
						zeroIndex := oneIndex - 1

						return (True)  ;* Continue enumerating since an Item had been returned.
					}
				}
			default:
				throw (ValueError("No matching Enumerator found for this many for-loop variables.", -2, numberOfVars))
		}
	}

	;--------------------------------------------------------??? Has ???----------------;

	DefaultHas_Call := Array.Prototype.GetOwnPropDesc("Has").Call

	Array.Prototype.DefineProp("Has", {Call: (this, index) => (DefaultHas_Call(this, index + (index >= 0)))})

	;------------------------------------------------------ InsertAt --------------;

	DefaultInsertAt_Call := Array.Prototype.GetOwnPropDesc("InsertAt").Call

	Array.Prototype.DefineProp("InsertAt", {Call: (this, index, values*) => (DefaultInsertAt_Call(this, index + (index >= 0), values*))})

	;------------------------------------------------------ RemoveAt --------------;

	DefaultRemoveAt_Call := Array.Prototype.GetOwnPropDesc("RemoveAt").Call

	Array.Prototype.DefineProp("RemoveAt", {Call: (this, index, length := 1) => ((length == 1) ? (DefaultRemoveAt_Call(this, index + (index >= 0))) : (DefaultRemoveAt_Call(this, index + (index >= 0), length)))})

	;------------------------------------------------------- Delete ---------------;

	DefaultDelete_Call := Array.Prototype.GetOwnPropDesc("Delete").Call

	Array.Prototype.DefineProp("Delete", {Call: (this, index) => (DefaultDelete_Call(this, index + (index >= 0)))})

	;--------------- Custom -------------------------------------------------------;
	;-------------------------------------------------------??? Print ???---------------;

	;* array.Print()
	;* Description:
		;* Converts the array into a string to more easily see the structure.
	Array.Prototype.DefineProp("Print", {Call: Print})

	Print(this) {
		if (length := this.Length) {
			string := "["

			for value in this {
				if (!IsSet(value)) {
					value := ""
				}

				string .= ((IsObject(value)) ? ((value.HasProp("Print")) ? (value.Print()) : (Type(value))) : ((IsNumber(value)) ? (RegExReplace(value, "S)^0+(?=\d\.?)|(?=\.).*?\K\.?0*$")) : (Format('"{}"', value)))) . ((A_Index < length) ? (", ") : ("]"))
			}
		}
		else {
			string := "[]"
		}

		return (string)
	}

	;------------------------------------------------------??? Compact ???--------------;

	;* array.Compact([recursive])
	;* Description:
		;* Remove all falsy values from an array.
	Array.Prototype.DefineProp("Compact", {Call: Compact})

	Compact(this, recursive := 0) {
		for i, v in (r := [], this) {
			if (v) {
				r.Push((recursive && v is Array) ? (v.Compact(recursive)) : (v))
			}
		}

		return (this := r)
	}

	;-------------------------------------------------------??? Empty ???---------------;

	;* array.Empty()
	;* Description:
		;* Removes all elements from an array.
	Array.Prototype.DefineProp("Empty", {Call: Empty})

	Empty(this) {
		this.RemoveAt(0, this.Length)

		return (this)
	}

	;------------------------------------------------------- Remove ---------------;

	;* array.Remove(value)
	;* Description:
		;* Removes all occurences of `value` from an array.
	Array.Prototype.DefineProp("Remove", {Call: Remove})

	Remove(this, value) {
		s := this.Length, i := -1

		while (++i != s) {
			if (this[i] == value) {  ;* No need to get and compare object pointers since that's done automatically in v2.
				this.RemoveAt(i--), s--
			}
		}

		return (this)
	}

	;------------------------------------------------------- Sample ---------------;

	;* array.Sample(number)
	;* Description:
		;* Returns a new array with `number` random elements from an array.
	Array.Prototype.DefineProp("Sample", {Call: Sample})

	Sample(this, number) {
		if (!this.Length) {
			throw (IndexError("The array is empty.", -1))
		}

		return (this.Clone().Slice(0, number).Shuffle())
	}

	;------------------------------------------------------??? Shuffle ???--------------;

	;* array.Shuffle([callback])
	;* Description:
		;* See https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle.
	Array.Prototype.DefineProp("Shuffle", {Call: Shuffle})

	Shuffle(this, callback := "") {
		if (callback && !(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}
		else {
			callback := Random
		}

		for i, v in (m := this.Length - 1, this) {
			r := callback.Call(i, m)
				, t := this[i], this[i] := this[r], this[r] := t
		}

		return (this)
	}

	;-------------------------------------------------------- Swap ----------------;

	;* array.Swap(index1, index2)
	;* Description:
		;* Swap any two elements in an array.
	Array.Prototype.DefineProp("Swap", {Call: Swap})

	Swap(this, index1, index2) {
		if (this.Length < 2) {
			throw (IndexError("The array has less than 2 elements.", -1))
		}

		t := this[index1], this[index1] := this[index2], this[index2] := t

		return (this)
	}

	;------------------------------------------------------- Unique ---------------;

	;* array.Unique()
	;* Description:
		;* Removes all duplicate values from an array such that all remaining values are unique.
	Array.Prototype.DefineProp("Unique", {Call: Unique})

	Unique(this) {
		i := this.Length

		while (--i != -1) {  ;* This is basically a `array.LastIndexOf()` method with a `array.IndexOf()` method inside of it but more efficient than using those methods as is.
			loop (v := this[i], i) {
				if (this[A_Index - 1] == v) {
					this.RemoveAt(i)

					break
				}
			}
		}

		return (this)
	}

	;----------------??? MDN ???--------------------------------------------------------;  ;: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array, https://javascript.info/array-methods
	;------------------------------------------------------- Concat ---------------;

	;* array.Concat(values*)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/concat.
	Array.Prototype.DefineProp("Concat", {Call: Concat})

	Concat(this, values*) {
		for i, v in (r := this.Clone(), values) {  ;~ Original array is untouched.
			if (v is Array) {
				if (v.Length) {  ;* Ignore if empty.
					r.Push(v*)
				}
			}
			else {
				r.Push(v)
			}
		}

		return (r)
	}

	;-------------------------------------------------------??? Every ???---------------;

	;* array.Every(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/every.
	;* Note:
		;~ Calling this method on an empty array will return true for any condition.
	Array.Prototype.DefineProp("Every", {Call: Every})

	Every(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				if ((v := this[i]) != "") {  ;~ `callback` is invoked only for indexes of the array which have assigned values; it is not invoked for indexes which have been deleted or which have never been assigned values.
					if (!callback.Call(v, i, this)) {
						return (False)
					}
				}
			}
			catch (IndexError) {
				break
			}
		}

		return (True)
	}

	;-------------------------------------------------------- Fill ----------------;

	;* array.Fill(value[, start, end])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/fill.
	Array.Prototype.DefineProp("Fill", {Call: Fill})

	Fill(this, value, start := 0, end := "") {
		loop (start := (start >= 0) ? (Min(s := this.Length, start)) : (Max((s := this.Length) + start, 0)), ((end != "") ? ((end >= 0) ? (Min(s, end)) : (Max(s + end, 0))) : s) - start) {
			this[start++] := value
		}

		return (this)
	}

	;------------------------------------------------------- Filter ---------------;

	;* array.Filter(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/filter.
	Array.Prototype.DefineProp("Filter", {Call: Filter})

	Filter(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		r := [], s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				if ((v := this[i]) != "") {  ;~ `callback` is invoked only for indexes of the array which have assigned values; it is not invoked for indexes which have been deleted or which have never been assigned values.
					if (callback.Call(v, i, this)) {  ;~ Array elements which do not pass the callbackFn test are skipped, and are not included in the new array.
						r.Push(v)
					}
				}
			}
			catch (IndexError) {
				break
			}
		}

		return (r)
	}

	;-------------------------------------------------------- Find ----------------;

	;* array.Find(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/find.
	Array.Prototype.DefineProp("Find", {Call: Find})

	Find(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				if (callback.Call(v := this[i], i, this)) {  ;~ `callback` is invoked for every index of the array, not just those with assigned values. This means it may be less efficient for sparse arrays, compared to methods that only visit assigned values.
					return (v)
				}
			}
			catch (IndexError) {
				break
			}
		}
	}

	;-----------------------------------------------------??? FindIndex ???-------------;

	;* array.FindIndex(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/findIndex.
	;* Note:
		;~ If the index of the first element in the array that passes the test is 0, the return value of findIndex will be interpreted as Falsy in conditional statements.
	Array.Prototype.DefineProp("FindIndex", {Call: FindIndex})

	FindIndex(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				if (callback.Call(this[i], i, this)) {  ;~ `callback` is invoked for every index of the array, not just those with assigned values. This means it may be less efficient for sparse arrays, compared to methods that only visit assigned values.
					return (i)
				}
			}
			catch (IndexError) {
				break
			}
		}

		return (-1)
	}

	;-------------------------------------------------------- Flat ----------------;

	;* array.Flat([depth])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/flat.
	Array.Prototype.DefineProp("Flat", {Call: Flat})

	Flat(this, depth := 1) {
		for i, v in (r := [], this) {
			if (v is Array && depth > 0) {
				r := r.Concat(v.Flat(depth - 1))
			}
			else if (v != "") {  ;~ Ignore empty elements.
				r.Push(v)
			}
		}

		return (r)
	}

	;------------------------------------------------------??? ForEach ???--------------;

	;* array.ForEach(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/forEach.
	Array.Prototype.DefineProp("ForEach", {Call: ForEach})

	ForEach(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				if ((v := this[i]) != "") {  ;~ `callback` is invoked only for indexes of the array which have assigned values; it is not invoked for indexes which have been deleted or which have never been assigned values.
					this[i] := callback.Call(v, i, this)
				}
			}
			catch (IndexError) {
				break
			}
		}
	}

	;------------------------------------------------------ Includes --------------;

	;* array.Includes(needle[, start])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/includes.
	;* Note:
		;~ Strings comparisons are case-sensitive.
	Array.Prototype.DefineProp("Includes", {Call: (this, needle, start := 0) => (start < this.Length && this.IndexOf(needle, start) != -1)})  ;~ If `start` is greater than or equal to the length of the array, the array will not be searched.

	;------------------------------------------------------??? IndexOf ???--------------;


	;* array.IndexOf(needle[, start])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/indexOf.
	;* Note:
		;~ Strings comparisons are case-sensitive.
	Array.Prototype.DefineProp("IndexOf", {Call: IndexOf})

	IndexOf(this, needle, start := 0) {
		loop (s := this.Length, start := (start >= 0) ? (Min(s, start)) : (Max(s + start, 0)), s - start) {
			if (this[start] == needle) {
				return (start)
			}

			start++
		}

		return (-1)
	}

	;-------------------------------------------------------- Join ----------------;

	;* array.Join([delimiter])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/join.
	Array.Prototype.DefineProp("Join", {Call: Join})

	Join(this, delimiter := ", ") {
		for i, v in (m := this.length - 1, this) {
			r .= (IsObject(v)) ? ((v is Array) ? (v.Join(delimiter)) : (Type(v))) : (v)

			if (i < m) {
				r .= delimiter
			}
		}

		return (r)
	}

	;----------------------------------------------------??? LastIndexOf ???------------;

	;* array.LastIndexOf(needle[, start])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/lastIndexOf.
	;* Note:
		;~ Strings comparisons are case-sensitive.
	Array.Prototype.DefineProp("LastIndexOf", {Call: LastIndexOf})

	LastIndexOf(this, needle, start := -1) {
		start := (start >= 0) ? (Min(this.Length - 1, start + 1)) : (Max(this.Length + start + 1, -1))

		while (--start != -1) {
			if (this[start] == needle) {
				return (start)
			}
		}

		return (-1)
	}

	;--------------------------------------------------------??? Map ???----------------;

	;* array.Map(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map.
	Array.Prototype.DefineProp("Map", {Call: Map})

	Map(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		r := [], s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				r.Push(callback.Call(this[i], i, this))
			}
			catch (IndexError) {
				break
			}
		}

		return (r)
	}

	;* array.Push(values*)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/push.
	Array.Prototype.DefineProp("Push", {Call: Push})

	Push(this, values*) {
		this.InsertAt(s := this.Length, values*)

		return (s + values.Length)
	}

	;------------------------------------------------------- Reduce ---------------;

	;* array.Reduce(callback[, initialValue])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/Reduce.
	;* Note:
		;~ If `initialValue` is not provided, `callback` will be executed starting at index 1, skipping the first index. If `initialValue` is provided, it will start at index 0.
	Array.Prototype.DefineProp("Reduce", {Call: Reduce})

	Reduce(this, callback, initialValue := "") {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		i := -1, s := this.Length

		if ((accumulator := initialValue) == "") {
			while (++i < s && (accumulator := this[i]) == "") {  ;~ If no `initialValue` is supplied, the first element in the array will be used as the initial `accumulator` value and not passed to `callback`.
				continue
			}

			if (i >= s) {
				throw (TypeError("The array is empty and no intital value was set.", -1))  ;~ Calling `.Reduce()` on an empty array without an initial value creates a TypeError.
			}
		}

		while (++i != s) {
			if ((v := this[i]) != "") {
				accumulator := callback.Call(accumulator, v, i, this)  ;~ The return value of `callback` is assigned to `accumulator`, whose value is remembered across each iteration throughout the array, and ultimately becomes the final, single resulting value.
			}
		}

		return (accumulator)  ;~ If the array only has one element (regardless of position) and no `initialValue` is provided, or if `initialValue` is provided but the array is empty, the solo value will be returned without calling `callback`.
	}

	;----------------------------------------------------??? ReduceRight ???------------;

	;* array.ReduceRight(callback[, initialValue])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/ReduceRight.
	Array.Prototype.DefineProp("ReduceRight", {Call: ReduceRight})

	ReduceRight(this, callback, initialValue := "") {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		i := this.Length

		if ((accumulator := initialValue) == "") {
			while (--i >= 0 && (accumulator := this[i]) == "") {  ;~ If no `initialValue` is supplied, the last element in the array will be used as the initial `accumulator` value and not passed to `callback`.
				continue
			}

			if (i < 0) {
				throw (TypeError("The array is empty and no intital value was set.", -1))  ;~ Calling `.ReduceRight()` on an empty array without an initial value creates a TypeError.
			}
		}

		while (--i != -1) {
			if ((v := this[i]) != "") {
				accumulator := callback.Call(accumulator, v, i, this)
			}
		}

		return (accumulator)  ;~ If the array only has one element (regardless of position) and no `initialValue` is provided, or if `initialValue` is provided but the array is empty, the solo value will be returned without calling `callback`.
	}

	;------------------------------------------------------??? Reverse ???--------------;

	;* array.Reverse()
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reverse.
	Array.Prototype.DefineProp("Reverse", {Call: Reverse})

	Reverse(this) {
		for i, v in (m := this.Length - 1, this) {
			this.InsertAt(m, this.RemoveAt(m - i))
		}

		return (this)
	}

	;-------------------------------------------------------??? Shift ???---------------;

	;* array.Shift()
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/shift.
	Array.Prototype.DefineProp("Shift", {Call: (this) => (this.RemoveAt(0))})

	;-------------------------------------------------------??? Slice ???---------------;

	;* array.Slice([start, end])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/slice.
	Array.Prototype.DefineProp("Slice", {Call: Slice})

	Slice(this, start := 0, end := "") {
		loop (r := [], start := (start >= 0) ? (Min(s := this.Length, start)) : (Max((s := this.Length) + start, 0)), ((end != "") ? ((end >= 0) ? (Min(s, end)) : (Max(s + end, 0))) : (s)) - start) {
			r.Push(this[start++])
		}

		return (r)
	}

	;-------------------------------------------------------- Some ----------------;

	;* array.Some(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/some.
	;* Note:
		;~ Calling this method on an empty array returns false for any condition.
	Array.Prototype.DefineProp("Some", {Call: Some})

	Some(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		s := this.Length, i := -1

		while (++i != s) {  ;~ The range of elements processed is set before the first invocation of `callback`. Therefore, `callback` will not run on elements that are appended to the array after the loop begins.
			try  {
				if ((v := this[i]) != "" && callback.Call(v, i, this)) {  ;~ `callback` is invoked only for indexes of the array which have assigned values; it is not invoked for indexes which have been deleted or which have never been assigned values.
					return (True)
				}
			}
			catch (IndexError) {
				break
			}
		}

		return (False)
	}

	;-------------------------------------------------------- Sort ----------------;

	;* array.Sort(callback)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/sort.
	Array.Prototype.DefineProp("Sort", {Call: Sort})

	Sort(this, callback) {
		if (!(callback is Func || callback is Closure)) {
			throw (TypeError(Format("{} is not a valid callback function.", Type(callback)), -1))
		}

		m := this.Length - 1, c := True

		while (c != False) {
			c := False

			loop (m) {
				if (callback.Call(this[i := A_Index - 1], this[A_Index]) > 0) {
					c := True

					t := this[i], this[i] := this[A_Index], this[A_Index] := t
				}
			}
		}

		return (this)
	}

	;------------------------------------------------------- Splice ---------------;

	;* array.Splice(start[, deleteCount, elements*])
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/splice.
	Array.Prototype.DefineProp("Splice", {Call: Splice})

	Splice(this, start, deleteCount := "", elements*) {
		loop (r := [], start := (start >= 0) ? (Min(s := this.Length, start)) : (Max((s := this.Length) + start, 0)), (deleteCount != "") ? (Max((s <= start + deleteCount) ? (s - start) : (deleteCount), 0)) : ((elements.Length) ? (0) : (s - start))) {
			r.Push(this.RemoveAt(start))
		}

		if (elements.Length) {
			this.InsertAt(start, elements*)
		}

		return (r)  ;~ If no elements are removed, an empty array is returned.
	}

	;------------------------------------------------------??? UnShift ???--------------;

	;* array.UnShift(elements*)
	;* Description:
		;* See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/unshift.
	Array.Prototype.DefineProp("UnShift", {Call: UnShift})

	UnShift(this, elements*) {
		this.InsertAt(0, elements*)

		return (this.Length)
	}
}