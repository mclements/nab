



(** Functions for controlling mobility processes.
  @author Henri Dubois-Ferriere.
 *)

val make_uniwaypoint_mobs : ?gran:float -> unit -> unit
  (** Create {!Mobs.mobility} objects that implement a uniform waypoint mobility
    model (see {!Mobs.uniwaypoint}). Optional gran indicates the mobility granularity. 
  *)

val make_borderwaypoint_mobs : ?gran:float -> unit -> unit
  (** Create {!Mobs.mobility} objects that implement a border waypoint mobility
    model (see {!Mobs.borderwaypoint}). Optional gran indicates the mobility granularity. 
  *)

val make_billiard_mobs : ?gran:float -> unit -> unit
  (** Create {!Mobs.mobility} objects that implement a border waypoint mobility
    model (see {!Mobs.billiard}). Optional gran indicates the mobility granularity. 
  *)

val make_epfl_waypoint_mobs : unit -> unit
  (** Create {!Mobs.mobility} objects that implement a waypoint mobility model
    over epfl campus (uses {!Epflcoords.l}). *)

val make_discrete_randomwalk_mobs : unit -> unit
  (** Create {!Mobs.mobility} objects that implement a discrete random walk 
    mobility model. *)

val set_speed_mps : ?nidopt:Common.nodeid_t -> float -> unit
  (** Set mobility speed in meters/sec. If optional nodeid is given, only that
    node's speed is set, otherwise all nodes are set to the given value *)

val start_node : Common.nodeid_t -> unit
  (** Starts mobility of given node. Idempotent. *)

(** Warning: multiple start/stops might  have faulty behavior, see
  general_todo.txt *)

val stop_node : Common.nodeid_t -> unit
  (** Stops mobility of given node. Idempotent.*)

val start_all : unit -> unit
  (** Starts mobility of all nodes. Idempotent.*)

val stop_all : unit -> unit
  (** Stops mobility of all nodes. Idempotent.*)


