# Offline fixtures for the CoNLL parser. The strings below are shaped like
# the text YAP's /yap/heb/joint endpoint returns, but use ASCII placeholders
# for the Hebrew forms so the tests do not depend on the testing environment's
# locale.
#
# md_lattice columns: FROM TO FORM LEMMA CPOSTAG POSTAG FEATS TOKEN
# dep_tree  columns: ID FORM LEMMA CPOSTAG POSTAG FEATS HEAD DEPREL

fixture_md_one_sentence <- paste(
  "0\t1\th\th\tDEF\tDEF\t_\t1",
  "1\t2\tylDym\tylD\tNN\tNN\tgen=M|num=P\t1",
  "2\t3\thlkw\thlK\tVB\tVB\tgen=M|num=P|tense=PAST\t2",
  "3\t4\tlbyt\tbyt\tNN\tNN\t_\t3",
  "4\t5\thspr\tspr\tNN\tNN\t_\t4",
  "5\t6\t.\tyyDOT\tyyDOT\tyyDOT\t_\t5",
  sep = "\n"
)

fixture_md_two_sentences <- paste0(
  fixture_md_one_sentence,
  "\n\n",
  paste(
    "0\t1\tywm\tywm\tNN\tNN\t_\t1",
    "1\t2\typh\typh\tJJ\tJJ\t_\t2",
    "2\t3\t.\tyyDOT\tyyDOT\tyyDOT\t_\t3",
    sep = "\n"
  )
)

fixture_dep_one_sentence <- paste(
  "1\th\th\tDEF\tDEF\t_\t2\tdef",
  "2\tylDym\tylD\tNN\tNN\tgen=M|num=P\t3\tsubj",
  "3\thlkw\thlK\tVB\tVB\tgen=M|num=P|tense=PAST\t0\tROOT",
  "4\tlbyt\tbyt\tNN\tNN\t_\t3\tobl",
  "5\thspr\tspr\tNN\tNN\t_\t4\tcompound",
  "6\t.\tyyDOT\tyyDOT\tyyDOT\tyyDOT\t3\tpunct",
  sep = "\n"
)
