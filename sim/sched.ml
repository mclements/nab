(*                                  *)
(* mws  multihop wireless simulator *)
(*                                  *)

(** Discrete event schedulers. *)


(** 
  There are currently two schedulers. One is list-based , and has 
  O(n) insert time and O(1) pop time, other is heap-based and has O(logn)
  insert and O(logn) pop time.

  For the list-based scheduler, multiple events scheduled at the same time
  (or at ASAP) are executed in FIFO order.

  For the heap based scheduler, multiple events scheduled at the same time
  (or at ASAP) are executed in undefined order.
*)

open Printf

type handler_t = Stop | Handler of (unit -> unit)
  (** The type of event handlers. *)

type sched_time_t = | ASAP (** Schedule as soon as possible. *)
		    | ALAP (** Schedule as late as possible. *)
		    | Time of Common.time_t  (** Schedule at given time. *)



(** The type of events. *)
type event_t = {
  handler:handler_t;
  time:Common.time_t;}

let set_time t = (
  (* check log level to avoid these ops when not necessary (this is going to
     be called a lot *)
  if !Log.current_log_level >= Log.LOG_INFO then (
    if ((floor (t /. 10.0)) <> (floor ((Common.get_time()) /. 10.0))) then (
      Log.log#log_info (lazy (sprintf "Time: %f\n" t));
    );
  );
  Common.set_time t
)    

(** The interface that any scheduler implementation must conform to. *)
class type virtual scheduler_t = 
object 


  method run : unit -> unit 
    (** Keep processing queued events until none left. *)

  
  method run_until : 
    continue:(unit -> bool) -> 
    unit 
    (** Same as #run except that continue() is called between each event, and
       processing stops if continue() returns false. *)

  method run_for : duration:Common.time_t -> unit
    (** Runs until no more events or duration secs passed, whichever
      occurs first. *)

  method objdescr : string

  method sched_in : f:(unit -> unit) -> t:Common.time_t -> unit
    (** Schedule function f() to be called in t simulated seconds. *)

  method sched_at : f:(unit -> unit) -> t:sched_time_t -> unit
    (** Schedule function f() to be called at simulated time t. *)

  method virtual private sched_event_at : ev:event_t -> unit

  method stop_in :  t:Common.time_t -> unit
    (** Tell the scheduler to stop running in t simulated seconds. *)

  method stop_at :  t:sched_time_t -> unit
    (** Tell the scheduler to stop running at simulated time t. *)

  method virtual private next_event : event_t option 
end


let compare ev1 ev2 = ev1.time < ev2.time

  
class virtual sched  = 

object(s)

  inherit Log.loggable

  method virtual private next_event : event_t option 

  method virtual private sched_event_at : ev:event_t -> unit

  initializer (
    objdescr <- "/sched/list"
  ) 
    
    
  method stop_at ~t =  s#sched_handler_at  ~handler:Stop ~t
    
  method stop_in ~t =  s#stop_at  ~t:(Time (t +. Common.get_time()))

  method private sched_handler_at ~handler ~t = (
    let str = ref "" in (

      match t with 
	| ASAP -> 
	    s#sched_event_at {handler=handler; time=Common.get_time()};
	| ALAP -> raise (Failure "schedList.sched_at: ALAP not implemented\n")
	| Time t -> (
	    if (t <= Common.get_time()) then 
	      raise (Failure "schedList.sched_at: attempt to schedule an event in the past");
	    s#sched_event_at {handler=handler; time=t};
	  );
    );
(*    s#log_debug (sprintf "scheduling event at %s" !str);*)
  )

  method sched_at ~f ~t = s#sched_handler_at ~handler:(Handler f) ~t
    
  method sched_in ~f ~t = s#sched_at ~f ~t:(Time (t +. Common.get_time()))

  method run_until ~continue = (
    try 
      while (true) do 
	match s#next_event with
	  | None -> raise Misc.Break
	  | Some ev -> 
	      begin
		set_time (ev.time);
		match ev.handler with
		  | Stop -> 
		      raise Misc.Break
		  | Handler h -> (
		      h();
		      if (not (continue())) then 
			raise Misc.Break;
		    )
	      end;
      done;
      
    with
      | Misc.Break -> () 
      | o -> raise o
    )

  method run_for ~duration = 
    let t = (Common.get_time()) in
    let continue  = (fun () -> (Common.get_time()) < duration +. t) in
    s#run_until ~continue

  method run() = s#run_until ~continue:(fun () -> true)

end

class  schedList = 
object
  inherit sched

  val ll = Linkedlist.create()

  method private next_event =  Linkedlist.pophead ~ll:ll 
    
  method private sched_event_at ~ev = 
    Linkedlist.insert ~ll:ll ~v:ev ~compare:compare

end



module Compare =
struct
  type t = event_t
  let compare ev1 ev2 = 
    if ev1.time = ev2.time then 0 
    else if ev1.time > ev2.time  then -1 else 1
      
end
module EventHeap = Heap.Imperative (Compare)

class  schedHeap = 
object
  inherit sched

  val heap = EventHeap.create 1024 

  method private next_event =  
    if EventHeap.is_empty heap then 
      None 
    else 
      Some (EventHeap.pop_maximum  heap)
    
  method private sched_event_at ~ev = 
    EventHeap.add  heap ev

end
