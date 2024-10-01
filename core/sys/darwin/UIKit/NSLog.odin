package objc_UIKit

foreign import "system:Foundation.framework"

@(link_prefix="NS", default_calling_convention="c")
foreign Foundation {
	Log    :: proc(str: ^String) ---
}

