package objc_UIKit

@(objc_class="UIScreen")
Screen :: struct {using _: Object}

@(objc_type=Screen, objc_name="mainScreen")
Screen_mainScreen :: proc "c" () -> ^Screen {
	return msgSend(^Screen, Screen, "mainScreen")
}
@(objc_type=Screen, objc_name="deepestScreen")
Screen_deepestScreen :: proc "c" () -> ^Screen {
	return msgSend(^Screen, Screen, "deepestScreen")
}
@(objc_type=Screen, objc_name="screens")
Screen_screens :: proc "c" () -> ^Array {
	return msgSend(^Array, Screen, "screens")
}
@(objc_type=Screen, objc_name="bounds")
Screen_bounds :: proc "c" (self: ^Screen) -> Rect {
	return msgSend(Rect, self, "bounds")
}
@(objc_type=Screen, objc_name="depth")
Screen_depth :: proc "c" (self: ^Screen) -> Depth {
	return msgSend(Depth, self, "depth")
}
@(objc_type=Screen, objc_name="visibleFrame")
Screen_visibleFrame :: proc "c" (self: ^Screen) -> Rect {
	return msgSend(Rect, self, "visibleFrame")
}
@(objc_type=Screen, objc_name="colorSpace")
Screen_colorSpace :: proc "c" (self: ^Screen) -> ^ColorSpace {
	return msgSend(^ColorSpace, self, "colorSpace")
}
@(objc_type=Screen, objc_name="backingScaleFactor")
Screen_backingScaleFactor :: proc "c" (self: ^Screen) -> Float {
	return msgSend(Float, self, "backingScaleFactor")
}
