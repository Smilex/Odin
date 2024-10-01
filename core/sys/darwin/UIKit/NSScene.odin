package objc_UIKit

@(objc_class="UIScene")
Scene :: struct {using _: Responder}

@(objc_class="UISceneSession")
SceneSession :: struct {using _: Object}

@(objc_type=SceneSession, objc_name="role")
SceneSession_role :: proc "c" (self: ^SceneSession) -> UInteger {
	return msgSend(UInteger, self, "role")
}

@(objc_class="UISceneConnectionOptions")
SceneConnectionOptions :: struct {using _: Object}

@(objc_class="UIWindowScene")
WindowScene :: struct {using _: Scene}

@(objc_type=WindowScene, objc_name="coordinateSpace")
WindowScene_coordinateSpace :: proc "c" (self: ^WindowScene) -> ^CoordinateSpace {
	return msgSend(^CoordinateSpace, self, "coordinateSpace")
}

@(objc_class="UICoordinateSpace")
CoordinateSpace :: struct {using _: Object}

@(objc_type=CoordinateSpace, objc_name="bounds")
CoordinateSpace_bounds :: proc "c" (self: ^CoordinateSpace) -> Rect {
	return msgSend(Rect, self, "bounds")
}

@(objc_class="UISceneConfiguration")
SceneConfiguration :: struct {using _: Object}

@(objc_type=SceneConfiguration, objc_name="init", objc_is_class_method=true)
SceneConfiguration_init :: proc "c" (name: ^String, role: UInteger) -> ^SceneConfiguration {
	return msgSend(^SceneConfiguration, SceneConfiguration, "configurationWithName:sessionRole:", name, role)
}

@(objc_type=SceneConfiguration, objc_name="setDelegateClass")
SceneConfiguration_setDelegateClass :: proc "c" (self: ^SceneConfiguration, delegate: Class) {
	msgSend(nil, self, "setDelegateClass:", delegate)
}
