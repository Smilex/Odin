package objc_UIKit

@(objc_class="UIViewController")
ViewController :: struct {using _: Responder}

@(objc_type=ViewController, objc_name="alloc", objc_is_class_method=true)
ViewController_alloc :: proc "c" () -> ^ViewController {
	return msgSend(^ViewController, ViewController, "alloc")
}

@(objc_type=ViewController, objc_name="init")
ViewController_init :: proc "c" (self: ^ViewController) -> ^ViewController {
	return msgSend(^ViewController, self, "init")
}

@(objc_type=ViewController, objc_name="viewDidLoad")
ViewController_viewDidLoad :: proc "c" (self: ^ViewController) {
	msgSend(nil, self, "viewDidLoad")
}

@(objc_type=ViewController, objc_name="setView")
ViewController_setView :: proc "c" (self: ^ViewController, view: ^View) {
	msgSend(nil, self, "setView:", view)
}

@(objc_type=ViewController, objc_name="view")
ViewController_view :: proc "c" (self: ^ViewController) -> ^View {
	return msgSend(^View, self, "view")
}
