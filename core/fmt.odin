#import "os.odin";
#import "mem.odin";
#import "utf8.odin";

DEFAULT_BUFFER_SIZE :: 1<<12;

Buffer :: struct {
	data:   []byte;
	length: int;
}

buffer_write :: proc(buf: ^Buffer, b: []byte) {
	if buf.length < buf.data.count {
		n := min(buf.data.count-buf.length, b.count);
		if n > 0 {
			copy(buf.data[buf.length:], b[:n]);
			buf.length += n;
		}
	}
}
buffer_write_string :: proc(buf: ^Buffer, s: string) {
	buffer_write(buf, s as []byte);
}
buffer_write_byte :: proc(buf: ^Buffer, b: byte) {
	if buf.length < buf.data.count {
		buf.data[buf.length] = b;
		buf.length += 1;
	}
}
buffer_write_rune :: proc(buf: ^Buffer, r: rune) {
	if r < utf8.RUNE_SELF {
		buffer_write_byte(buf, r as byte);
		return;
	}

	b, n := utf8.encode_rune(r);
	buffer_write(buf, b[:n]);
}

Fmt_Info :: struct {
	minus:     bool;
	plus:      bool;
	space:     bool;
	zero:      bool;
	hash:      bool;
	width_set: bool;
	prec_set:  bool;

	width:     int;
	prec:      int;

	reordered:      bool;
	good_arg_index: bool;

	buf: ^Buffer;
	arg: any; // Temporary
}



fprint :: proc(fd: os.Handle, args: ...any) -> int {
	data: [DEFAULT_BUFFER_SIZE]byte;
	buf := Buffer{data[:], 0};
	bprint(^buf, ...args);
	os.write(fd, buf.data[:buf.length]);
	return buf.length;
}

fprintln :: proc(fd: os.Handle, args: ...any) -> int {
	data: [DEFAULT_BUFFER_SIZE]byte;
	buf := Buffer{data[:], 0};
	bprintln(^buf, ...args);
	os.write(fd, buf.data[:buf.length]);
	return buf.length;
}
fprintf :: proc(fd: os.Handle, fmt: string, args: ...any) -> int {
	data: [DEFAULT_BUFFER_SIZE]byte;
	buf := Buffer{data[:], 0};
	bprintf(^buf, fmt, ...args);
	os.write(fd, buf.data[:buf.length]);
	return buf.length;
}


print :: proc(args: ...any) -> int {
	return fprint(os.stdout, ...args);
}
println :: proc(args: ...any) -> int {
	return fprintln(os.stdout, ...args);
}
printf :: proc(fmt: string, args: ...any) -> int {
	return fprintf(os.stdout, fmt, ...args);
}


fprint_type :: proc(fd: os.Handle, info: ^Type_Info) {
	data: [DEFAULT_BUFFER_SIZE]byte;
	buf := Buffer{data[:], 0};
	buffer_write_type(^buf, info);
	os.write(fd, buf.data[:buf.length]);
}


buffer_write_type :: proc(buf: ^Buffer, ti: ^Type_Info) {
	if ti == nil {
		return;
	}

	using Type_Info;
	match type info : ti {
	case Named:
		buffer_write_string(buf, info.name);
	case Integer:
		match {
		case ti == type_info(int):  buffer_write_string(buf, "int");
		case ti == type_info(uint): buffer_write_string(buf, "uint");
		default:
			buffer_write_string(buf, if info.signed { give "i" } else { give "u"});
			fi := Fmt_Info{buf = buf};
			fmt_int(^fi, 8*info.size as u64, false, 'd');
		}

	case Float:
		match info.size {
		case 4: buffer_write_string(buf, "f32");
		case 8: buffer_write_string(buf, "f64");
		}
	case String:  buffer_write_string(buf, "string");
	case Boolean: buffer_write_string(buf, "bool");
	case Pointer:
		if info.elem == nil {
			buffer_write_string(buf, "rawptr");
		} else {
			buffer_write_string(buf, "^");
			buffer_write_type(buf, info.elem);
		}
	case Maybe:
		buffer_write_string(buf, "?");
		buffer_write_type(buf, info.elem);
	case Procedure:
		buffer_write_string(buf, "proc");
		if info.params == nil {
			buffer_write_string(buf, "()");
		} else {
			count := (info.params as ^Tuple).fields.count;
			if count == 1 { buffer_write_string(buf, "("); }
			buffer_write_type(buf, info.params);
			if count == 1 { buffer_write_string(buf, ")"); }
		}
		if info.results != nil {
			buffer_write_string(buf, " -> ");
			buffer_write_type(buf, info.results);
		}
	case Tuple:
		count := info.fields.count;
		if count != 1 { buffer_write_string(buf, "("); }
		for i : 0..<count {
			if i > 0 { buffer_write_string(buf, ", "); }

			f := info.fields[i];

			if f.name.count > 0 {
				buffer_write_string(buf, f.name);
				buffer_write_string(buf, ": ");
			}
			buffer_write_type(buf, f.type_info);
		}
		if count != 1 { buffer_write_string(buf, ")"); }

	case Array:
		buffer_write_string(buf, "[");
		fi := Fmt_Info{buf = buf};
		fmt_int(^fi, info.count as u64, false, 'd');
		buffer_write_string(buf, "]");
		buffer_write_type(buf, info.elem);
	case Slice:
		buffer_write_string(buf, "[");
		buffer_write_string(buf, "]");
		buffer_write_type(buf, info.elem);
	case Vector:
		buffer_write_string(buf, "[vector ");
		fi := Fmt_Info{buf = buf};
		fmt_int(^fi, info.count as u64, false, 'd');
		buffer_write_string(buf, "]");
		buffer_write_type(buf, info.elem);

	case Struct:
		buffer_write_string(buf, "struct ");
		if info.packed  { buffer_write_string(buf, "#packed "); }
		if info.ordered { buffer_write_string(buf, "#ordered "); }
		buffer_write_string(buf, "{");
		for field, i : info.fields {
			if i > 0 {
				buffer_write_string(buf, ", ");
			}
			buffer_write_string(buf, field.name);
			buffer_write_string(buf, ": ");
			buffer_write_type(buf, field.type_info);
		}
		buffer_write_string(buf, "}");

	case Union:
		buffer_write_string(buf, "union {");
		for field, i : info.fields {
			if i > 0 {
				buffer_write_string(buf, ", ");
			}
			buffer_write_string(buf, field.name);
			buffer_write_string(buf, ": ");
			buffer_write_type(buf, field.type_info);
		}
		buffer_write_string(buf, "}");

	case Raw_Union:
		buffer_write_string(buf, "raw_union {");
		for field, i : info.fields {
			if i > 0 {
				buffer_write_string(buf, ", ");
			}
			buffer_write_string(buf, field.name);
			buffer_write_string(buf, ": ");
			buffer_write_type(buf, field.type_info);
		}
		buffer_write_string(buf, "}");

	case Enum:
		buffer_write_string(buf, "enum ");
		buffer_write_type(buf, info.base);
		buffer_write_string(buf, " {}");

	}
}


make_any :: proc(type_info: ^Type_Info, data: rawptr) -> any {
	a: any;
	a.type_info = type_info;
	a.data = data;
	return a;
}


bprint :: proc(buf: ^Buffer, args: ...any) -> int {
	is_type_string :: proc(info: ^Type_Info) -> bool {
		using Type_Info;
		if info == nil {
			return false;
		}

		match type i : type_info_base(info) {
		case String:
			return true;
		}
		return false;
	}

	fi: Fmt_Info;
	fi.buf = buf;

	prev_string := false;
	for arg, i : args {
		is_string := arg.data != nil && is_type_string(arg.type_info);
		if i > 0 && !is_string && !prev_string {
			buffer_write_rune(buf, ' ');
		}
		fmt_value(^fi, arg, 'v');
		prev_string = is_string;
	}
	return buf.length;
}

bprintln :: proc(buf: ^Buffer, args: ...any) -> int {
	fi: Fmt_Info;
	fi.buf = buf;

	for arg, i : args {
		if i > 0 {
			buffer_write_rune(buf, ' ');
		}
		fmt_value(^fi, arg, 'v');
	}
	buffer_write_rune(buf, '\n');
	return buf.length;
}






parse_int :: proc(s: string, offset: int) -> (int, int, bool) {
	is_digit :: proc(r: rune) -> bool #inline {
		return '0' <= r && r <= '9';
	}

	result := 0;
	ok := true;

	i := 0;
	for _ : offset..<s.count {
		c := s[offset] as rune;
		if !is_digit(c) {
			break;
		}
		i += 1;

		result *= 10;
		result += (c - '0') as int;
	}

	return result, offset, i != 0;
}

arg_number :: proc(fi: ^Fmt_Info, arg_index: int, format: string, offset: int, arg_count: int) -> (int, int, bool) {
	parse_arg_number :: proc(format: string) -> (int, int, bool) {
		if format.count < 3 {
			return 0, 1, false;
		}

		for i : 1..<format.count {
			if format[i] == ']' {
				width, new_index, ok := parse_int(format, 1);
				if !ok || new_index != i {
					return 0, i+1, false;
				}
				return width-1, i+1, true;
			}
		}

		return 0, 1, false;
	}


	if format.count <= offset || format[offset] != '[' {
		return arg_index, offset, false;
	}
	fi.reordered = true;
	index, width, ok := parse_arg_number(format[offset:]);
	if ok && 0 <= index && index < arg_count {
		return index, offset+width, true;
	}
	fi.good_arg_index = false;
	return arg_index, offset+width, false;
}

int_from_arg :: proc(args: []any, arg_index: int) -> (int, int, bool) {
	num := 0;
	new_arg_index := arg_index;
	ok := true;
	if arg_index < args.count {
		arg := args[arg_index];
		arg.type_info = type_info_base(arg.type_info);
		match type i : arg {
		case int:  num = i;
		case i8:   num = i as int;
		case i16:  num = i as int;
		case i32:  num = i as int;
		case i64:  num = i as int;
		case u8:   num = i as int;
		case u16:  num = i as int;
		case u32:  num = i as int;
		case u64:  num = i as int;
		default:
			ok = false;
		}
	}

	return num, new_arg_index, ok;
}


fmt_bad_verb :: proc(using fi: ^Fmt_Info, verb: rune) {
	buffer_write_string(buf, "%!");
	buffer_write_rune(buf, verb);
	buffer_write_byte(buf, '(');
	if arg.type_info != nil {
		buffer_write_type(buf, arg.type_info);
		buffer_write_byte(buf, '=');
		fmt_value(fi, arg, 'v');
	} else {
		buffer_write_string(buf, "<nil>");
	}
	buffer_write_byte(buf, ')');
}

fmt_bool :: proc(using fi: ^Fmt_Info, b: bool, verb: rune) {
	match verb {
	case 't', 'v':
		buffer_write_string(buf, if b { give "true" } else { give "false" });
	default:
		fmt_bad_verb(fi, verb);
	}
}


fmt_write_padding :: proc(fi: ^Fmt_Info, width: int) {
	if width <= 0 {
		return;
	}
	pad_byte: byte = ' ';
	if fi.zero {
		pad_byte = '0';
	}

	count := min(width, fi.buf.data.count-fi.buf.length);
	start := fi.buf.length;
	for i : start..<count {
		fi.buf.data[i] = pad_byte;
	}
	fi.buf.length += count;
}

fmt_integer :: proc(fi: ^Fmt_Info, u: u64, base: int, signed: bool, digits: string) {
	negative := signed && (u as i64) < 0;
	if negative {
		u = -u;
	}
	buf: [256]byte;
	if fi.width_set || fi.prec_set {
		width := fi.width + fi.prec + 3;
		if width > buf.count {
			// TODO(bill):????
			panic("fmt_integer buffer overrun. Width and precision too big");
		}
	}

	prec := 0;
	if fi.prec_set {
		prec = fi.prec;
		if prec == 0 && u == 0 {
			old_zero := fi.zero;
			fi.zero = false;
			fmt_write_padding(fi, fi.width);
			fi.zero = old_zero;
			return;
		}
	} else if fi.zero && fi.width_set {
		prec = fi.width;
		if negative || fi.plus || fi.space {
			// There needs to be space for the "sign"
			prec -= 1;
		}
	}

	i := buf.count;

	match base {
	case 2, 8, 10, 16:
		break;
	default:
		panic("fmt_integer: unknown base, whoops");
	}

	while b := base as u64; u >= b {
		i -= 1;
		next := u / b;
		buf[i] = digits[u%b];
		u = next;
	}
	i -= 1;
	buf[i] = digits[u];
	while i > 0 && prec > buf.count-i {
		i -= 1;
		buf[i] = '0';
	}

	if fi.hash {
		i -= 1;
		match base {
		case 2:  buf[i] = 'b';
		case 8:  buf[i] = 'o';
		case 10: buf[i] = 'd';
		case 16: buf[i] = digits[16];
		}
		i -= 1;
		buf[i] = '0';
	}

	if negative {
		i -= 1;
		buf[i] = '-';
	} else if fi.plus {
		i -= 1;
		buf[i] = '+';
	} else if fi.space {
		i -= 1;
		buf[i] = ' ';
	}

	old_zero := fi.zero;
	defer fi.zero = old_zero;
	fi.zero = false;

	if !fi.width_set || fi.width == 0 {
		buffer_write(fi.buf, buf[i:]);
	} else {
		width := fi.width - utf8.rune_count(buf[i:] as string);
		if fi.minus {
			// Right pad
			buffer_write(fi.buf, buf[i:]);
			fmt_write_padding(fi, width);
		} else {
			// Left pad
			fmt_write_padding(fi, width);
			buffer_write(fi.buf, buf[i:]);
		}
	}

}

__DIGITS_LOWER := "0123456789abcdefx";
__DIGITS_UPPER := "0123456789ABCDEFX";

fmt_rune :: proc(fi: ^Fmt_Info, r: rune) {
	buffer_write_rune(fi.buf, r);
}

fmt_int :: proc(fi: ^Fmt_Info, u: u64, signed: bool, verb: rune) {
	match verb {
	case 'v': fmt_integer(fi, u, 10, signed, __DIGITS_LOWER);
	case 'b': fmt_integer(fi, u,  2, signed, __DIGITS_LOWER);
	case 'o': fmt_integer(fi, u,  8, signed, __DIGITS_LOWER);
	case 'd': fmt_integer(fi, u, 10, signed, __DIGITS_LOWER);
	case 'x': fmt_integer(fi, u, 16, signed, __DIGITS_LOWER);
	case 'X': fmt_integer(fi, u, 16, signed, __DIGITS_UPPER);
	case 'c': fmt_rune(fi, u as rune);
	case 'U':
		r := u as rune;
		if r < 0 || r > utf8.MAX_RUNE {
			fmt_bad_verb(fi, verb);
		} else {
			buffer_write_string(fi.buf, "U+");
			fmt_integer(fi, u, 16, false, __DIGITS_UPPER);
		}

	default:
		fmt_bad_verb(fi, verb);
	}
}
fmt_float :: proc(fi: ^Fmt_Info, v: f64, bits: int, verb: rune) {
	// TODO(bill): Actually print a float correctly
	// THIS IS FUCKING SHIT!

	match verb {
	case 'e', 'E', 'f', 'F', 'g', 'G':
		break;
	default:
		fmt_bad_verb(fi, verb);
		return;
	}

	f := v;

	if f == 0 {
		buffer_write_byte(fi.buf, '0');
		return;
	}

	if f < 0 {
		buffer_write_byte(fi.buf, '-');
		f = -f;
	}
	i := f as u64;
	fmt_int(fi, i, false, 'd');
	f -= i as f64;
	buffer_write_byte(fi.buf, '.');

	decimal_places := 5;
	if bits == 64 {
		decimal_places = 9;
	}
	if fi.prec_set {
		decimal_places = fi.prec;
	}

	while mult: f64 = 10.0; decimal_places >= 0 {
		i = (f * mult) as u64;
		fmt_int(fi, i, false, 'd');
		f -= i as f64 / mult;
		mult *= 10;
		decimal_places -= 1;
	}
}
fmt_string :: proc(fi: ^Fmt_Info, s: string, verb: rune) {
	match verb {
	case 'v', 's':
		buffer_write_string(fi.buf, s);
	default:
		fmt_bad_verb(fi, verb);
	}
}

fmt_pointer :: proc(fi: ^Fmt_Info, p: rawptr, verb: rune) {
	if verb != 'p' {
		fmt_bad_verb(fi, verb);
		return;
	}
	u := p as uint as u64;
	if !fi.hash {
		buffer_write_string(fi.buf, "0x");
	}
	fmt_integer(fi, u, 16, false, __DIGITS_UPPER);
}


fmt_value :: proc(fi: ^Fmt_Info, v: any, verb: rune) {
	if v.data == nil || v.type_info == nil {
		buffer_write_string(fi.buf, "<nil>");
		return;
	}

	using Type_Info;
	match type info : v.type_info {
	case Named:
		if verb != 'v' {
			fmt_bad_verb(fi, verb);
			return;
		}

		a := make_any(info.base, v.data);
		match type b : info.base {
		case Struct:
			buffer_write_string(fi.buf, info.name);
			buffer_write_byte(fi.buf, '{');
			for f, i : b.fields {
				if i > 0 {
					buffer_write_string(fi.buf, ", ");
				}
				buffer_write_string(fi.buf, f.name);
				// bprint_any(fi.buf, f.offset);
				buffer_write_string(fi.buf, " = ");
				data := v.data as ^byte + f.offset;
				fmt_arg(fi, make_any(f.type_info, data), 'v');
			}
			buffer_write_byte(fi.buf, '}');

		default:
			fmt_value(fi, a, verb);
		}

	case Boolean: fmt_arg(fi, v, verb);
	case Float:   fmt_arg(fi, v, verb);
	case Integer: fmt_arg(fi, v, verb);
	case String:  fmt_arg(fi, v, verb);

	case Pointer:
		fmt_pointer(fi, (v.data as ^rawptr)^, verb);

	case Maybe:
		// TODO(bill): Correct verbs for Maybe types?
		size := mem.size_of_type_info(info.elem);
		data := slice_ptr(v.data as ^byte, size+1);
		if data[size] != 0 {
			fmt_arg(fi, make_any(info.elem, v.data), verb);
		} else {
			buffer_write_string(fi.buf, "nil");
		}

	case Array:
		if verb != 'v' {
			fmt_bad_verb(fi, verb);
			return;
		}

		buffer_write_byte(fi.buf, '[');
		defer buffer_write_byte(fi.buf, ']');
		for i : 0..<info.count {
			if i > 0 {
				buffer_write_string(fi.buf, ", ");
			}
			data := v.data as ^byte + i*info.elem_size;
			fmt_arg(fi, make_any(info.elem, data), 'v');
		}

	case Slice:
		if verb != 'v' {
			fmt_bad_verb(fi, verb);
			return;
		}

		buffer_write_byte(fi.buf, '[');
		defer buffer_write_byte(fi.buf, ']');
		slice := v.data as ^[]byte;
		for i : 0..<slice.count {
			if i > 0 {
				buffer_write_string(fi.buf, ", ");
			}
			data := slice.data + i*info.elem_size;
			fmt_arg(fi, make_any(info.elem, data), 'v');
		}

	case Vector:
		is_bool :: proc(type_info: ^Type_Info) -> bool {
			match type info : type_info {
			case Named:
				return is_bool(info.base);
			case Boolean:
				return true;
			}
			return false;
		}

		buffer_write_byte(fi.buf, '<');
		defer buffer_write_byte(fi.buf, '>');

		if is_bool(info.elem) {
			return;
		}

		for i : 0..<info.count {
			if i > 0 {
				buffer_write_string(fi.buf, ", ");
			}

			data := v.data as ^byte + i*info.elem_size;
			fmt_value(fi, make_any(info.elem, data), 'v');
		}

	case Struct:
		buffer_write_byte(fi.buf, '{');
		defer buffer_write_byte(fi.buf, '}');

		for f, i : info.fields {
			if i > 0 {
				buffer_write_string(fi.buf, ", ");
			}
			buffer_write_string(fi.buf, f.name);
			buffer_write_string(fi.buf, " = ");
			data := v.data as ^byte + f.offset;
			ti := f.type_info;
			fmt_value(fi, make_any(ti, data), 'v');
		}

	case Union:
		buffer_write_string(fi.buf, "(union)");
	case Raw_Union:
		buffer_write_string(fi.buf, "(raw_union)");

	case Enum:
		fmt_value(fi, make_any(info.base, v.data), verb);

	case Procedure:
		buffer_write_type(fi.buf, v.type_info);
		buffer_write_string(fi.buf, " @ ");
		fmt_pointer(fi, (v.data as ^rawptr)^, 'p');
	}
}

fmt_arg :: proc(fi: ^Fmt_Info, arg: any, verb: rune) {
	if arg.data == nil || arg.type_info == nil {
		buffer_write_string(fi.buf, "<nil>");
		return;
	}
	fi.arg = arg;

	if verb == 'T' { // Type Info
		buffer_write_type(fi.buf, arg.type_info);
		return;
	}

	base_arg := arg;
	base_arg.type_info = type_info_base(base_arg.type_info);
	match type a : base_arg {
	case bool:    fmt_bool(fi, a, verb);
	case f32:     fmt_float(fi, a as f64, 32, verb);
	case f64:     fmt_float(fi, a, 64, verb);

	case int:     fmt_int(fi, a as u64, true, verb);
	case i8:      fmt_int(fi, a as u64, true, verb);
	case i16:     fmt_int(fi, a as u64, true, verb);
	case i32:     fmt_int(fi, a as u64, true, verb);
	case i64:     fmt_int(fi, a as u64, true, verb);
	case uint:    fmt_int(fi, a as u64, false, verb);
	case u8:      fmt_int(fi, a as u64, false, verb);
	case u16:     fmt_int(fi, a as u64, false, verb);
	case u32:     fmt_int(fi, a as u64, false, verb);
	case u64:     fmt_int(fi, a as u64, false, verb);
	case string:  fmt_string(fi, a, verb);
	default:      fmt_value(fi, arg, verb);
	}

}


bprintf :: proc(b: ^Buffer, fmt: string, args: ...any) -> int {
	fi := Fmt_Info{};
	end := fmt.count;
	arg_index := 0;
	was_prev_index := false;
	while i := 0; i < end {
		fi = Fmt_Info{buf = b, good_arg_index = true};

		prev_i := i;
		while i < end && fmt[i] != '%' {
			i += 1;
		}
		if i > prev_i {
			buffer_write_string(b, fmt[prev_i:i]);
		}
		if i >= end {
			break;
		}

		// Process a "verb"
		i += 1;


		while i < end {
			skip_loop := false;
			c := fmt[i];
			match c {
			case '+':
				fi.plus = true;
			case '-':
				fi.minus = true;
				fi.zero = false;
			case ' ':
				fi.space = true;
			case '#':
				fi.hash = true;
			case '0':
				fi.zero = !fi.minus;
			default:
				skip_loop = true;
			}

			if skip_loop {
				break;
			}
			i += 1;
		}

		arg_index, i, was_prev_index = arg_number(^fi, arg_index, fmt, i, args.count);

		// Width
		if i < end && fmt[i] == '*' {
			i += 1;
			fi.width, arg_index, fi.width_set = int_from_arg(args, arg_index);
			if !fi.width_set {
				buffer_write_string(b, "%!(BAD WIDTH)");
			}

			if fi.width < 0 {
				fi.width = -fi.width;
				fi.minus = true;
				fi.zero  = false;
			}
			was_prev_index = false;
		} else {
			fi.width, i, fi.width_set = parse_int(fmt, i);
			if was_prev_index && fi.width_set { // %[6]2d
				fi.good_arg_index = false;
			}
		}

		// Precision
		if i < end && fmt[i] == '.' {
			i += 1;
			if was_prev_index { // %[6].2d
				fi.good_arg_index = false;
			}
			arg_index, i, was_prev_index = arg_number(^fi, arg_index, fmt, i, args.count);
			if i < end && fmt[i] == '*' {
				i += 1;
				fi.prec, arg_index, fi.prec_set = int_from_arg(args, arg_index);
				if fi.prec < 0 {
					fi.prec = 0;
					fi.prec_set = false;
				}
				if !fi.prec_set {
					buffer_write_string(fi.buf, "%!(BAD PRECISION)");
				}
				was_prev_index = false;
			} else {
				fi.prec, i, fi.prec_set = parse_int(fmt, i);
				if !fi.prec_set {
					fi.prec_set = true;
					fi.prec = 0;
				}
			}
		}

		if !was_prev_index {
			arg_index, i, was_prev_index = arg_number(^fi, arg_index, fmt, i, args.count);
		}

		if i >= end {
			buffer_write_string(b, "%!(NO VERB)");
			break;
		}

		verb, w := utf8.decode_rune(fmt[i:]);
		i += w;

		if verb == '%' {
			buffer_write_byte(b, '%');
		} else if !fi.good_arg_index {
			buffer_write_string(b, "%!(BAD ARGUMENT NUMBER)");
		} else if arg_index >= args.count {
			buffer_write_string(b, "%!(MISSING ARGUMENT)");
		} else {
			fmt_arg(^fi, args[arg_index], verb);
			arg_index += 1;
		}
	}

	if !fi.reordered && arg_index < args.count {
		buffer_write_string(b, "%!(EXTRA ");
		for arg, index : args[arg_index:] {
			if index > 0 {
				buffer_write_string(b, ", ");
			}
			if arg.data == nil || arg.type_info == nil {
				buffer_write_string(b, "<nil>");
			} else {
				fmt_arg(^fi, arg, 'v');
			}
		}
		buffer_write_string(b, ")");
	}

	return b.length;
}
