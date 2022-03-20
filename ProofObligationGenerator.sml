structure ProofObligationGenerator =
struct
	exception ProofObligationGeneratorError of string
  fun po_generate model imp =
    let
        val velist = values_equal_list imp
        val rwmch = replace_values model velist
        val rwimp = replace_values imp velist
        val modelvar = model_var_list model
        val linkinv = link_invariant modelvar rwimp
        val importmchs = imports_machine_list rwimp
    in
      importmchs
    end
  and
    find_clause cname clauses =
    let
      val clause = List.find (fn (s, _) => s=cname) clauses
    in
      if clause <> NONE then
        valOf(clause)
      else
        raise ProofObligationGeneratorError ("POG error : missing " ^ cname ^ " clause in model")
      end
  and
    model_var_list (BMch(machinename, _, clauses)) =
      let
        val avclause = find_clause "ABSTRACT_VARIABLES" clauses
        fun extract_var_list (BC_AVARIABLES varlist) = varlist
      in
        extract_var_list (#2(avclause))
      end
    | model_var_list _ = raise ProofObligationGeneratorError "POG error : this is not model"
  and
    link_invariant varlist (BImp(_, _, _, clauses)) =
      let
        val invclause = find_clause "INVARIANT" clauses
        fun extract_linkinv mvar (inv :: invlist) =
          if (is_tree_member mvar inv) then
            inv :: extract_linkinv mvar invlist
          else
            extract_linkinv mvar invlist
        | extract_linkinv _ [] = []
        fun extract_linkinv_list ((Var mvar) :: vlist) (Inv as (BC_INVARIANT (BP_list invlist))) =
          extract_linkinv (hd mvar) invlist @ extract_linkinv_list vlist Inv
        | extract_linkinv_list [] _ = []
      in
        extract_linkinv_list  varlist (#2(invclause))
      end
  and
    is_tree_member elem tree =
      case tree of
        BE_Leaf(_, Var varlist)                               => List.exists (fn x => x=elem) varlist
      | BE_Node1(_, _, node)                                  => is_tree_member elem node
      | BE_Node2(_, _, left, right)                           => (is_tree_member elem left) orelse (is_tree_member elem right)
      | BE_NodeN(_, _, nodelist)                              => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) nodelist)
      | BE_Fnc(_,  node1, node2)                              => (is_tree_member elem node1) orelse (is_tree_member elem node2)
      | BE_Img(_,  node1, node2)                              => (is_tree_member elem node1) orelse (is_tree_member elem node2)
      | BE_ExSet(_, nodelist)                                 => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) nodelist)
      | BE_InSet(_, _, BP_list nodelist)                      => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) nodelist)
      | BE_Seq(_, nodelist)                                   => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) nodelist)
      | BE_ForAny(_, BP_list nodelist1, BP_list nodelist2)    => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) (nodelist1 @ nodelist2))
      | BE_Exists(_, BP_list nodelist)                        => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) nodelist)
      | BE_Lambda(_, _, BP_list nodelist, node)               => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) (node :: nodelist))
      | BE_Sigma(_, _, BP_list nodelist, node)                => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) (node :: nodelist))
      | BE_Pi(_, _, BP_list nodelist, node)                   => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) (node :: nodelist))
      | BE_Inter(_, _, BP_list nodelist, node)                => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) (node :: nodelist))
      | BE_Union(_, _, BP_list nodelist, node)                => List.foldr (fn (x, y) => x orelse y) false (List.map (is_tree_member elem) (node :: nodelist))
      | _                                                     => false
  and
    values_equal_list (BImp (_, _, _, clauses)) =
      let
        val valclause = find_clause "VALUES" clauses
        fun extract_values ((BE_Node2 (_, Keyword "Eq", BE_Leaf (_, Var varlist), expr)) :: vallist) = (hd(varlist), expr) :: extract_values vallist
        | extract_values [] = []
        | extract_values _ = raise ProofObligationGeneratorError "POG error : including expression except \"Eq\" in VALUES"
      in
        case #2(valclause) of
          (BC_VALUES (BP_list vallist)) => extract_values vallist
        | _                             => raise ProofObligationGeneratorError "POG error : missing expression list in VALUES clause"
      end
  and
    replace_values comp eqlist =
      case comp of
        (BMch (mname, params, clauses))        => BMch (mname, params, (replace_values_sub clauses eqlist))
      | (BImp (mname, rname, params, clauses)) => BImp (mname, rname, params, (replace_values_sub clauses eqlist))
  and
    replace_values_sub [] _ = []
    | replace_values_sub (clause :: clauselist) eqlist =
      case clause of
        (cname, BC_INVARIANT (BP_list exprlist))  => (cname, BC_INVARIANT (BP_list (replace_expr_list eqlist exprlist))) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_ASSERTIONS (BP_list exprlist)) => (cname, BC_ASSERTIONS (BP_list (replace_expr_list eqlist exprlist))) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_SEES mchlist)                  => (cname, BC_SEES (replace_mch_list eqlist mchlist)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_INCLUDES mchlist)              => (cname, BC_INCLUDES (replace_mch_list eqlist mchlist)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_PROMOTES mchlist)              => (cname, BC_PROMOTES (replace_mch_list eqlist mchlist)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_EXTENDS mchlist)               => (cname, BC_EXTENDS (replace_mch_list eqlist mchlist)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_USES mchlist)                  => (cname, BC_USES (replace_mch_list eqlist mchlist)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_IMPORTS mchlist)               => (cname, BC_IMPORTS (replace_mch_list eqlist mchlist)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_INITIALISATION subst)          => (cname, BC_INITIALISATION (replace_subst eqlist subst)) :: (replace_values_sub clauselist eqlist)
      | (cname, BC_OPERATIONS oplist)             => (cname, BC_OPERATIONS (replace_op_list eqlist oplist)) :: (replace_values_sub clauselist eqlist)
      | other                                     => other :: (replace_values_sub clauselist eqlist)
  and
    replace_expr (ident, rep) expr =
    case expr of
        BE_Leaf(btype, Var varlist)                            => if hd(varlist) = ident then rep else BE_Leaf(btype, Var varlist)
      | BE_Node1(btype, key, node)                             => BE_Node1(btype, key, replace_expr (ident, rep) node)
      | BE_Node2(btype, key, left, right)                      => BE_Node2(btype, key, replace_expr (ident, rep) left, replace_expr (ident, rep) right)
      | BE_NodeN(btype, key, nodelist)                         => BE_NodeN(btype, key, List.map (replace_expr (ident, rep)) nodelist)
      | BE_Fnc(btype,  node1, node2)                           => BE_Fnc(btype, replace_expr (ident, rep) node1, replace_expr (ident, rep) node2)
      | BE_Img(btype,  node1, node2)                           => BE_Img(btype, replace_expr (ident, rep) node1, replace_expr (ident, rep) node2)
      | BE_ExSet(btype, nodelist)                              => BE_ExSet(btype, List.map (replace_expr (ident, rep)) nodelist)
      | BE_InSet(btype, tkn, BP_list nodelist)                 => BE_InSet(btype, tkn, BP_list (List.map (replace_expr (ident, rep)) nodelist))
      | BE_Seq(btype, nodelist)                                => BE_Seq(btype, List.map (replace_expr (ident, rep)) nodelist)
      | BE_ForAny(btype, BP_list nodelist1, BP_list nodelist2) => BE_ForAny(btype, BP_list (List.map (replace_expr (ident, rep)) nodelist1), BP_list (List.map (replace_expr (ident, rep)) nodelist2))
      | BE_Exists(btype, BP_list nodelist)                     => BE_Exists(btype, BP_list (List.map (replace_expr (ident, rep)) nodelist))
      | BE_Lambda(btype, tkn, BP_list nodelist, node)          => BE_Lambda(btype, tkn, BP_list (List.map (replace_expr (ident, rep)) nodelist), replace_expr (ident, rep) node)
      | BE_Sigma(btype, tkn, BP_list nodelist, node)           => BE_Sigma(btype, tkn, BP_list (List.map (replace_expr (ident, rep)) nodelist), replace_expr (ident, rep) node)
      | BE_Pi(btype, tkn, BP_list nodelist, node)              => BE_Pi(btype, tkn, BP_list (List.map (replace_expr (ident, rep)) nodelist), replace_expr (ident, rep) node)
      | BE_Inter(btype, tkn, BP_list nodelist, node)           => BE_Inter(btype, tkn, BP_list (List.map (replace_expr (ident, rep)) nodelist), replace_expr (ident, rep) node)
      | BE_Union(btype, tkn, BP_list nodelist, node)           => BE_Union(btype, tkn, BP_list (List.map (replace_expr (ident, rep)) nodelist), replace_expr (ident, rep) node)
      | other                                                  => other
  and
    replace_expr_list eqlist (expr :: exprlist) =
      (replace_expr_eqlist eqlist expr) :: (replace_expr_list eqlist exprlist)
    | replace_expr_list _ [] = []
  and
    replace_mch_list eqlist ((BMchInst (mname, exprlist)) :: mchlist) =
      (BMchInst (mname, replace_expr_list eqlist exprlist)) :: (replace_mch_list eqlist mchlist)
    | replace_mch_list _ [] = []
  and
    replace_expr_eqlist (eq :: eqlist) expr =
      replace_expr_eqlist eqlist (replace_expr eq expr)
    | replace_expr_eqlist [] expr = expr
  and
    replace_subst eqlist subst =
      case subst of
        BS_Block(sub)                                    => BS_Block(replace_subst eqlist sub)
      | BS_Identity                                      => BS_Identity
      | BS_Precondition(BP_list exprlist, sub)           => BS_Precondition(BP_list (replace_expr_list eqlist exprlist), (replace_subst eqlist sub))
      | BS_Assertion(BP_list exprlist, sub)              => BS_Assertion(BP_list (replace_expr_list eqlist exprlist), (replace_subst eqlist sub))
      | BS_Choice(sublist)                               => BS_Choice(List.map (replace_subst eqlist) sublist)
      | BS_If(iflist)                                    => BS_If(List.map (fn ((BP_list x), y) => ((BP_list (replace_expr_list eqlist x)), replace_subst eqlist y)) iflist)
      | BS_Select(selist)                                => BS_Select(List.map (fn ((BP_list x), y) => ((BP_list (replace_expr_list eqlist x)), replace_subst eqlist y)) selist)
      | BS_Case(expr, calist)                            => BS_Case((replace_expr_eqlist eqlist expr), (List.map (fn (x, y) => (replace_expr_list eqlist x, replace_subst eqlist y)) calist))
      | BS_Any(tkn, BP_list exprlist, sub)               => BS_Any(tkn, BP_list (replace_expr_list eqlist exprlist), (replace_subst eqlist sub))
      | BS_Let(lelist, sub)                              => BS_Let((List.map (fn (x, y) => (x, replace_expr_eqlist eqlist y)) lelist), (replace_subst eqlist sub))
      | BS_BecomesElt(expr1, expr2)                      => BS_BecomesElt((replace_expr_eqlist eqlist expr1), (replace_expr_eqlist eqlist expr2))
      | BS_BecomesSuchThat(exprlist1, BP_list exprlist2) => BS_BecomesSuchThat((replace_expr_list eqlist exprlist1), BP_list (replace_expr_list eqlist exprlist2))
      | BS_Call(exprlist1, tkn, exprlist2)               => BS_Call((replace_expr_list eqlist exprlist1), tkn, (replace_expr_list eqlist exprlist2))
      | BS_BecomesEqual(expr1, expr2)                    => BS_BecomesEqual(replace_expr_eqlist eqlist expr1, replace_expr_eqlist eqlist expr2)
      | BS_BecomesEqual_list(exprlist1, exprlist2)       => BS_BecomesEqual_list((replace_expr_list eqlist exprlist1), (replace_expr_list eqlist exprlist2))
      | BS_Simultaneous(sublist)                         => BS_Simultaneous(List.map (replace_subst eqlist) sublist)
  and
    replace_op_list eqlist (BOp(opname, ret, arg, sub) :: oplist) =
      BOp(opname, ret, arg, (replace_subst eqlist sub)) :: (replace_op_list eqlist oplist)
    | replace_op_list _ [] = []
  and
    imports_machine_list (BImp (_, _, _, clauses)) =
      let
        val impclause = find_clause "IMPORTS" clauses
      in
        case impclause of
          (_, (BC_IMPORTS mchlist)) => lib_tree_list mchlist
      end
  and
    lib_tree (varlist) =
    case List.length(varlist) of
        1 => (NONE, Parser.parse(lexer (Utils.fileToString ((hd varlist) ^ ".mch"))))
      | 2 => (SOME (hd varlist) Parser.parse(lexer (Utils.fileToString ((hd (tl varlist)) ^ ".mch"))))
      | _ => raise ProofObligationGeneratorError "POG error : wrong machine name in IMPORTS clause"
  and
    lib_tree_list [] = []
    | lib_tree_list (BMchInst(Var varlist, arglist) :: mchlist) =
      let
        val (libname, libtree) = lib_tree varlist
        val pelist = lib_param_eqlist libtree arglist
        val rwlibtree = replace_values libtree pelist
      in
        rwlibtree :: (lib_tree_list mchlist)
      end
  and
    lib_param_eqlist (BMch(_, paramlist, _)) arglist =
      let
        fun arg_eq_param ((Var [param]) :: paramlist) (arg :: alist) =
          (param, arg) :: (arg_eq_param paramlist alist)
        | arg_eq_param [] [] = []
        | arg_eq_param _ _ = raise ProofObligationGeneratorError "POG error : wrong number argument for imported machine"
      in
        arg_eq_param paramlist arglist
      end
end