(*                                  *)
(* mws  multihop wireless simulator *)
(*                                  *)

let initial_hash_size = 1000

type nodeDB_state_t = Common.enc_t option array 

class type nodeDB_t = 
object 
  method add_encounter : nid:Common.nodeid_t -> enc:Common.enc_t -> unit
  method last_encounter : nid:Common.nodeid_t -> Common.enc_t option
  method encounter_age : nid:Common.nodeid_t -> Common.time_t 
  method num_encounters : int
  method dump_state : node_cnt:int ->  nodeDB_state_t
  method load_state : dbstate:nodeDB_state_t -> unit
end


class nodeDB ~ntargets : nodeDB_t = 
object(s: #nodeDB_t)

  val enc_arr = Array.make ntargets None

  method add_encounter ~nid:nid ~enc:enc = 
    enc_arr.(nid) <- Some enc
      
  method last_encounter ~nid = enc_arr.(nid) 
    
  method encounter_age ~nid = 
    match s#last_encounter ~nid:nid with
	None -> max_float
      | Some encounter -> Common.enc_age encounter

  method num_encounters = 
    Array.fold_right
      (fun encopt count  -> count + if encopt <> None then 1 else 0) enc_arr 0

  method dump_state ~node_cnt = 
    Array.init node_cnt (fun i -> s#last_encounter i)

  method load_state ~dbstate = 
    Array.iteri
      (fun i encopt -> 
	match encopt with
	  | None -> ()
	  | Some enc -> s#add_encounter ~nid:i ~enc:enc
      ) dbstate
end

