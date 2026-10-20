extends RefCounted
## 등각 카메라 일치 — 2D 맵(Iso: TW 48 · TH 24 → 타일 96×48, 2:1)과 같은 투영을 3D 직교 카메라로 만든다.
##  방위각 45° (카메라가 +c,+r 쪽에서 -c,-r 쪽을 봄), 고도각 = asin(TH/TW) = 30°
##  월드: x = 격자 c, z = 격자 r, y = 위. 타일 한 변 = 1 유닛 = PPU 픽셀 (화면 가로 대각선 = TW*2 = 96px 이 되도록)
##  화면 = ((x - z) * TW, (x + z) * TH - y * cos(고도) * PPU)

const TW := 48.0
const TH := 24.0
const PPU := 67.88225099390856     # TW * sqrt(2)
const ELEV := 0.5235987755982988   # 30° = asin(TH / TW)
const VERT := 58.78787              # 높이 1 유닛이 화면에서 차지하는 px = PPU * cos(30°)

## 카메라가 보는 방향 (월드)
static func forward() -> Vector3:
	var h := cos(ELEV) / sqrt(2.0)
	return Vector3(-h, -sin(ELEV), -h)


static func cam_basis() -> Basis:
	return Basis.looking_at(forward(), Vector3.UP)


## 월드 점 → 2D 맵 화면 좌표 (원점 = 월드 (0,0,0) = 격자 (0,0) 윗꼭짓점)
static func to_screen(p: Vector3) -> Vector2:
	return Vector2((p.x - p.z) * TW, (p.x + p.z) * TH - p.y * VERT)


## 격자 칸 가운데 (c, r) 의 월드 좌표
static func tile_center(c: int, r: int, y: float = 0.0) -> Vector3:
	return Vector3(c + 0.5, y, r + 0.5)


## 카메라를 만들어 줌 — 직교, 뷰포트 높이 vp_h(px) 가 정확히 vp_h/ppu_k 월드 유닛
##  k = 화면 1px 당 그림 픽셀 수 (1 = 화면과 같은 도트 크기)
static func make_camera(vp_h: float, k: float = 1.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = vp_h / (PPU * k)
	cam.near = 0.05
	cam.far = 60.0
	return cam


## 조준점(월드) 을 화면 가운데에 두도록 카메라 자리 잡기
static func aim(cam: Camera3D, target: Vector3) -> void:
	var b := cam_basis()
	cam.transform = Transform3D(b, target - forward() * 25.0)


## 월드 원점의 발이 뷰포트 (cw, ch) 안에서 (cw/2, foot_y) 픽셀에 오도록 한 조준점
static func target_for_foot(origin: Vector3, ch: float, foot_y: float, k: float) -> Vector3:
	var up := cam_basis().y
	return origin + up * ((foot_y - ch * 0.5) / (PPU * k))
