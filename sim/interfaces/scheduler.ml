



(** Interface into discrete event schedulers. 
  @author Henri Dubois-Ferriere.
*)



type  sched_time_t = 
  | ASAP (** Schedule as soon as possible. *)
  | ALAP (** Schedule as late as possible. *)
  | Time of Time.time_t  (** Schedule at given time. *)
      

(** The virtual scheduler class. Contains all logic which is independent of
  the underlying data structure used to keep events.
  All that is left for a concrete class is to implement two virtual methods,
  allowing to insert and remove events into whatever data structure the
  concrete class uses. *)
class type t = 
object

  inherit Log.inheritable_loggable 

  method sched_at : f:(unit -> unit) -> t:sched_time_t -> unit
    (** Schedule the event [f] to run at time [t]. *)

  method sched_in : f:(unit -> unit) -> t:float -> unit
    (** Schedule the event [f] to run [t] simulated seconds from now. *)

  method stop_at : t:sched_time_t -> unit
    (** Schedule a "stop" event at time [t]. A stop event interrupts the
      scheduler, and control returns to the point where [run*] was called.
      Future scheduled events remain in the scheduler. *)

  method stop_in : t:float -> unit
    (** Schedule a "stop" event to run [t] simulated seconds from now. *)

  method run : unit -> unit
    (** Start running the event loop. Events are processed until the event
      queue is empty, or a "stop" event is encountered. *)

  method run_for : duration:float -> unit
    (** Start running the event loop. Events are processed until [duration]
      simulated seconds have elapsed, the event queue is empty, or a "stop"
      event is encountered. *)

  method run_until : continue:(unit -> bool) -> unit
    (** Start running the event loop. Events are processed until [continue()]
      evaluates to [false], the event queue is empty, or a "stop"
      event is encountered. *)

end

