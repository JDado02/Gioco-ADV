class_name MultiMeshHelper
## Funzioni di supporto per i MultiMesh usati da folla, nemici e proiettili.
##
## Per le prestazioni non si chiama set_instance_transform() per ogni istanza:
## si riempie un PackedFloat32Array e lo si assegna in blocco a MultiMesh.buffer.
## Formato del buffer (TRANSFORM_3D): 12 float per istanza, matrice 3x4 per righe.

const FLOAT_PER_ISTANZA := 12


## Crea un MultiMesh con il numero massimo di istanze già allocato (pool).
static func crea(mesh: Mesh, max_istanze: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = max_istanze
	mm.visible_instance_count = 0
	# Volume fisso che copre tutta l'area di gioco: evita il ricalcolo
	# dell'ingombro a ogni fotogramma e culling sbagliati.
	mm.custom_aabb = AABB(Vector3(-40, -5, -140), Vector3(80, 30, 170))
	return mm


## Crea il buffer vuoto della dimensione giusta per un MultiMesh.
static func crea_buffer(max_istanze: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(max_istanze * FLOAT_PER_ISTANZA)
	return buf


## Scrive nel buffer la trasformazione di un'istanza:
## posizione, rotazione attorno all'asse verticale (yaw) e scala uniforme.
static func scrivi(buf: PackedFloat32Array, indice: int, pos: Vector3, yaw: float, scala: float = 1.0) -> void:
	var c := cos(yaw) * scala
	var s := sin(yaw) * scala
	var o := indice * FLOAT_PER_ISTANZA
	buf[o] = c
	buf[o + 1] = 0.0
	buf[o + 2] = s
	buf[o + 3] = pos.x
	buf[o + 4] = 0.0
	buf[o + 5] = scala
	buf[o + 6] = 0.0
	buf[o + 7] = pos.y
	buf[o + 8] = -s
	buf[o + 9] = 0.0
	buf[o + 10] = c
	buf[o + 11] = pos.z
