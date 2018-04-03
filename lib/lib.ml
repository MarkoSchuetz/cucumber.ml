type outcome = Pass | Fail | Pending | Undefined | Skip
                                     
let string_of_outcome = function
  | Pass -> "."
  | Fail -> "F"
  | Pending -> "P"
  | Undefined -> "U"
  | Skip -> "-"
               
type 'a step = {
    regex : Re.re;
    step : ('a option -> Re.groups option -> Step.arg -> ('a option * outcome))    
  }

type 'a t = {
    before_hooks : (string -> unit) list;
    after_hooks : (string -> unit) list;
    steps : 'a step list    
  }

let empty = {
    after_hooks = [];
    before_hooks = [];
    steps = [];
  }

let _Before f cucc =
  let reg_before_hooks = cucc.before_hooks in
  { cucc with before_hooks = f :: reg_before_hooks }

let _After f cucc =
  let reg_after_hooks = cucc.after_hooks in
  { cucc with after_hooks = f :: reg_after_hooks }
  
let _Given re f cucc =
  let reg_steps = cucc.steps in
  { cucc with steps = { regex = re; step = f }::reg_steps }

let _When = _Given
let _Then = _Given
          
let find str {regex; step} =
  Re.execp regex str

let actuate user_step str arg state =
  let groups = (Re.exec_opt user_step.regex str) in
  user_step.step state groups arg
  
let run cucc state step =
  match (List.filter (find step.Step.text) cucc.steps) with
  | [user_step] ->
     actuate user_step step.Step.text step.Step.argument state
  | [] ->
     print_endline ("Could not find step: " ^ step.Step.text);
     (None, Undefined)
  | _ ->
     print_endline ("Ambigious match: " ^ step.Step.text);
     (None, Undefined)

let load_feature_file fname =
  let pickleLst = Gherkin.load_feature_file fname in
  List.rev_map (fun p -> {p with Pickle.steps = (List.rev p.Pickle.steps)}) pickleLst
  
let extract_last_state_run cucc outcome_accum step =
  match outcome_accum with
  | [] ->
     let outcome = run cucc None step in
     outcome::outcome_accum     
  | (state, out)::xs ->
     let outcome = run cucc state step in
     outcome::outcome_accum

let execute_before_hooks before_hooks pickel_name =
  Base.List.iter (Base.List.rev before_hooks) (fun f -> f pickel_name)

let execute_after_hooks after_hooks pickel_name =
  Base.List.iter (Base.List.rev after_hooks) (fun f -> f pickel_name)

let run_pickle cucc p =
  execute_before_hooks cucc.before_hooks p.Pickle.name;
  let outcomeLst = Base.List.fold p.Pickle.steps ~init:[] ~f:(extract_last_state_run cucc) in
  execute_after_hooks cucc.after_hooks p.Pickle.name;
  outcomeLst
  
let execute cucc =
  let pickleLst = load_feature_file Sys.argv.(1) in
  match pickleLst with
  | [] -> print_endline "Empty Pickle list"
  | _ ->
     let outcomeLst = List.flatten (Base.List.map pickleLst (run_pickle cucc)) in
     Base.List.iter outcomeLst (fun (state, out) -> (print_string (string_of_outcome out))) ;
     print_newline ()         

let fail = (None, Fail)
let pass = (None, Pass)
let pass_with_state state = (Some state, Pass)
