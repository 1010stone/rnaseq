#{{{ header
source("me.fun.r")
t_cfg
fi = file.path('~/data/genome/B73', "v37/t2.tsv")
t_gs = read_tsv(fi, col_types = 'ccccciic') %>% 
    filter(etype == 'exon') %>% 
    group_by(gid, tid) %>% 
    summarise(size = sum(end - beg + 1)) %>%
    group_by(gid) %>%
    summarise(size = max(size))
#}}}

sid = 'me99c'
#{{{ mapping stats
Sys.setenv(R_CONFIG_ACTIVE = sid)
diri = file.path(dird, '08_raw_output', sid, 'multiqc_data')
dirw = file.path(dird, '11_qc', sid)
if(!dir.exists(dirw)) system(sprintf("mkdir -p %s", dirw))
th = get_read_list(dird, sid)
tiss = unique(th$Tissue); genos = unique(th$Genotype); treas = unique(th$Treatment)
reps = unique(th$Replicate)
#
tt = read_multiqc(diri, th)
fo = file.path(dirw, '10.mapping.stat.tsv')
write_tsv(tt, fo)
#}}}

#{{{ obtain raw read counts, normalize and save
fi = file.path(diri, '../featurecounts.tsv')
t_rc = read_tsv(fi)
#
tm = t_rc %>% gather(SampleID, ReadCount, -gid)
res = readcount_norm(tm, t_gs)
tl = res$tl; tm = res$tm
#
fo = file.path(dirw, '20.rc.norm.rda')
save(tl, tm, file = fo)
#}}}

#{{{ read from 20.rc.norm.rda
fi = file.path(dirw, '20.rc.norm.rda')
x = load(fi)
x
#}}}

#{{{ prepare for hclust and pca 
tw = tm %>% select(SampleID, gid, CPM) %>% spread(SampleID, CPM)
t_exp = tm %>% group_by(gid) %>% summarise(n.exp = sum(CPM>=1))
gids = t_exp %>% filter(n.exp >= (ncol(tw)-1) * .8) %>% pull(gid)
e = tw %>% filter(gid %in% gids) %>% select(-gid)
dim(e)
#}}}

#{{{ hclust
cor_opt = "pearson"
hc_opt = "ward.D"
plot_title = sprintf("dist: %s\nhclust: %s", cor_opt, hc_opt)
e.c.dist <- as.dist(1-cor(e, method = cor_opt))
e.c.hc <- hclust(e.c.dist, method = hc_opt)
hc = e.c.hc
tree = as.phylo(e.c.hc)
#
tp = th %>% mutate(taxa = SampleID, lab = SampleID) 
if(length(tiss)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Tissue), lab)
if(length(genos)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Genotype), lab)
if(length(treas)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Treatment), lab)
if(length(reps)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Replicate), lab)
tp = tp %>% select(taxa, everything())
fo = sprintf("%s/21.cpm.hclust.pdf", dirw)
plot_hclust_tree(tree, tp, fo, 
                 labsize = config::get("hc.labsize"), 
                 x.expand = config::get("hc.x.expand"),
                 x.off = config::get("hc.x.off"), 
                 wd = config::get("hc.wd"), ht = config::get("hc.ht"))
#}}}

#{{{ PCA
pca <- prcomp(asinh(e), center = F, scale. = F)
x = pca['rotation'][[1]]
y = summary(pca)$importance
y[,1:5]
xlab = sprintf("PC1 (%.01f%%)", y[2,1]*100)
ylab = sprintf("PC2 (%.01f%%)", y[2,2]*100)
#
tp = as_tibble(x[,1:5]) %>%
    add_column(SampleID = rownames(x)) %>%
    left_join(th, by = 'SampleID') %>%
    mutate(Treatment = factor(Treatment), Replicate = factor(Replicate))
fo = sprintf("%s/22.pca.pdf", dirw)
plot_pca(tp, fo, opt = config::get("pca.opt"), labsize = config::get("pca.labsize"),
         wd = config::get("pca.wd"), ht = config::get("pca.ht"))
#}}}

#{{{ #identify mis-labelled replicate
cls = cutree(hc, h = .01)
tcl = tibble(SampleID = names(cls), grp = as.integer(cls))
th2 = th %>% inner_join(tcl, by = 'SampleID')
th3 = th2 %>% group_by(Genotype) %>% 
    summarise(nrep = length(Replicate), ngrp = length(unique(grp))) %>%
    ungroup() %>%
    filter(nrep > 1, ngrp > 1)
th2 %>% filter(Genotype %in% th3$Genotype) %>% print(n=40)
#}}}

#{{{ generate corrected read list me??.c.tsv
if(sid == 'me14c') {
    th = th %>% filter(! SampleID %in% c("SRR254169"))
} else if(sid == 'me14d') {
    th = th %>% filter(! SampleID %in% c("SRR1573518", 'SRR1573513'))
} else if(sid == 'me17a') {
    th = th %>%
        mutate(Tissue = ifelse(SampleID == 'SRR445601', 'tassel', Tissue)) %>%
        mutate(Tissue = ifelse(SampleID == 'SRR445416', 'tassel', Tissue)) %>%
        mutate(Genotype = ifelse(SampleID == 'SRR426798', 'Mo17', Genotype)) %>%
        mutate(Genotype = ifelse(SampleID == 'SRR426814', 'M37W', Genotype))
} else if(sid == 'me99b') {
    gts = c("B73", "Mo17", "B73xMo17")
    tissues = sort(unique(th$Tissue))
    th = th %>% 
        filter(Genotype %in% gts, ! SampleID %in% c('BR207', 'BR230', "BR235"))
}
write_tsv(th, fh2, na = '')
#}}}


#{{{ ##me99d - enders stress response 3' RNA-Seq
#{{{ hclust tree
cor_opt = "pearson"
hc_opt = "ward.D"
plot_title = sprintf("dist: %s\nhclust: %s", cor_opt, hc_opt)
e.c.dist <- as.dist(1-cor(e, method = cor_opt))
e.c.hc <- hclust(e.c.dist, method = hc_opt)
hc = e.c.hc
tree = as.phylo(e.c.hc)

tp = tl %>% inner_join(th, by = 'SampleID') %>%
    mutate(taxa = SampleID,
           lab = sprintf("%s %s %s", Tissue, Genotype, Treatment)) %>%
    select(taxa, everything())
p1 = ggtree(tree) +
    #geom_tiplab(size = 4, color = 'black') +
    scale_x_continuous(expand = c(0,0), limits=c(-.02,3.3)) +
    scale_y_discrete(expand = c(.01,0)) +
    theme_tree2()
p1 = p1 %<+% tp +
    #geom_tiplab(aes(label = lab), size = 2, offset = 0.04) +
    geom_text(aes(label = lab), size = 2.5, nudge_x = .01, hjust = 0)
fo = sprintf("%s/21.cpm.hclust.pdf", dirw)
ggsave(p1, filename = fo, width = 8, height = 10)
#}}}

#{{{ PCA
pca <- prcomp(asinh(e), center = F, scale. = F)
x = pca['rotation'][[1]]
y = summary(pca)$importance
y[,1:5]
xlab = sprintf("PC1 (%.01f%%)", y[2,1]*100)
ylab = sprintf("PC2 (%.01f%%)", y[2,2]*100)
#
tp = as_tibble(x[,1:5]) %>%
    add_column(SampleID = rownames(x)) %>%
    left_join(th, by = 'SampleID')
p1 = ggplot(tp, aes(x = PC1, y = PC2, shape = Genotype, color = Tissue)) +
    geom_point(size = 1.5) +
    #geom_label_repel() +
    scale_x_continuous(name = xlab) +
    scale_y_continuous(name = ylab) +
    scale_color_d3() +
    #scale_shape_manual(values = c(16, 4)) +
    theme_bw() +
    #theme(axis.ticks.length = unit(0, 'lines')) +
    theme(plot.margin = unit(c(.2,.2,.2,.2), "lines")) +
    theme(legend.position = c(1,1), legend.justification = c(1,1)) +
    theme(legend.direction = "vertical", legend.background = element_blank()) +
    theme(legend.title = element_blank(), legend.key.size = unit(.8, 'lines'), legend.key.width = unit(.8, 'lines'), legend.text = element_text(size = 9)) +
    guides(shape = guide_legend(ncol = 1, byrow = T))
fp = sprintf("%s/22.pca.pdf", dirw)
ggsave(p1, filename = fp, width = 8, height = 8)
#}}}
#}}}

#{{{ ##me99e - settles endosperm
#{{{ hclust tree
cor_opt = "pearson"
hc_opt = "ward.D"
plot_title = sprintf("dist: %s\nhclust: %s", cor_opt, hc_opt)
e.c.dist <- as.dist(1-cor(e, method = cor_opt))
e.c.hc <- hclust(e.c.dist, method = hc_opt)
hc = e.c.hc
tree = as.phylo(e.c.hc)

tp = tl %>% inner_join(th, by = 'SampleID') %>%
    mutate(taxa = SampleID,
           lab = sprintf("%s %s %s", Tissue, Genotype, Replicate)) %>%
    select(taxa, everything())
p1 = ggtree(tree) +
    #geom_tiplab(size = 4, color = 'black') +
    scale_x_continuous(expand = c(0,0), limits=c(-.02,5.5)) +
    scale_y_discrete(expand = c(.01,0)) +
    theme_tree2()
p1 = p1 %<+% tp +
    #geom_tiplab(aes(label = lab), size = 2, offset = 0.04) +
    geom_text(aes(label = lab), size = 2.5, nudge_x = .01, hjust = 0)
fo = sprintf("%s/21.cpm.hclust.pdf", dirw)
ggsave(p1, filename = fo, width = 6, height = 8)
#}}}

#{{{ PCA
pca <- prcomp(asinh(e), center = F, scale. = F)
x = pca['rotation'][[1]]
y = summary(pca)$importance
y[,1:5]
xlab = sprintf("PC1 (%.01f%%)", y[2,1]*100)
ylab = sprintf("PC2 (%.01f%%)", y[2,2]*100)
#
tp = as_tibble(x[,1:5]) %>%
    add_column(SampleID = rownames(x)) %>%
    left_join(th, by = 'SampleID')
p1 = ggplot(tp, aes(x = PC1, y = PC2, shape = Genotype, color = Tissue)) +
    geom_point(size = 1.5) +
    #geom_label_repel() +
    scale_x_continuous(name = xlab) +
    scale_y_continuous(name = ylab) +
    scale_color_d3() +
    #scale_shape_manual(values = c(16, 4)) +
    theme_bw() +
    #theme(axis.ticks.length = unit(0, 'lines')) +
    theme(plot.margin = unit(c(.2,.2,.2,.2), "lines")) +
    theme(legend.position = c(0,1), legend.justification = c(0,1)) +
    theme(legend.direction = "vertical", legend.background = element_blank()) +
    theme(legend.title = element_blank(), legend.key.size = unit(.8, 'lines'), legend.key.width = unit(.8, 'lines'), legend.text = element_text(size = 9)) +
    guides(shape = guide_legend(ncol = 1, byrow = T))
fp = sprintf("%s/22.pca.pdf", dirw)
ggsave(p1, filename = fp, width = 6, height = 6)
#}}}
#}}}


# combined datasets
sid = 'mec03'
#{{{ collect featurecounts data & normalize
Sys.setenv(R_CONFIG_ACTIVE = sid)
sids = str_split(config::get("sids"), "[\\+]")[[1]] 
sids
dirw = file.path(dird, '11_qc', sid)
if(!dir.exists(dirw)) system(sprintf("mkdir -p %s", dirw))
#
th = tibble(); t_rc = tibble()
for (sid1 in sids) {
    diri = file.path(dird, '08_raw_output', sid1, 'multiqc_data')
    th1 = get_read_list(dird, sid1)
    th1 = th1 %>% mutate(sid = sid1) %>% select(sid, everything())
    if(sid1 == 'me99b') {
        th1 = th1 %>% filter(Genotype == 'B73')
    } else if(sid1 == 'me13b') {
        th1 = th1 %>% filter(!str_detect(Treatment, "ET"))
    } else if(sid1 == 'me12a') {
        th1 = th1 %>% filter(Treatment == 'WT')
    }
    th = rbind(th, th1)
    fi = file.path(diri, '../featurecounts.tsv')
    t_rc1 = read_tsv(fi) %>% select(one_of(c('gid', th1$SampleID)))
    stopifnot(ncol(t_rc1) == nrow(th1) + 1)
    if(nrow(t_rc) == 0)
        t_rc = t_rc1
    else {
        t_rc = t_rc %>% inner_join(t_rc1, by = 'gid')
    }
}
dim(th); dim(t_rc)
th %>% dplyr::count(sid)
#
tm = t_rc %>% gather(SampleID, ReadCount, -gid)
res = readcount_norm(tm, t_gs)
tl = res$tl; tm = res$tm
#}}}

#{{{ merge reps and save to 20.rc.norm.rda
res = merge_reps(th, tm)
th = res$th; tm = res$tm
fo = file.path(dirw, '20.rc.norm.rda')
save(th, tm, file = fo)
#}}}

#{{{ read from 20.rc.norm.rda
fi = file.path(dirw, '20.rc.norm.rda')
x = load(fi)
x
#}}}

#{{{ prepare for hclust and pca 
tw = tm %>% select(SampleID, gid, CPM) %>% spread(SampleID, CPM)
t_exp = tm %>% group_by(gid) %>% summarise(n.exp = sum(CPM>=1))
gids = t_exp %>% filter(n.exp >= (ncol(tw)-1) * .7) %>% pull(gid)
e = tw %>% filter(gid %in% gids) %>% select(-gid)
dim(e)
#}}}

#{{{ hclust
tiss = unique(th$Tissue); genos = unique(th$Genotype); treas = unique(th$Treatment)
cor_opt = "pearson"
hc_opt = "ward.D"
plot_title = sprintf("dist: %s\nhclust: %s", cor_opt, hc_opt)
e.c.dist <- as.dist(1-cor(e, method = cor_opt))
e.c.hc <- hclust(e.c.dist, method = hc_opt)
hc = e.c.hc
tree = as.phylo(e.c.hc)
#
tp = th %>% mutate(taxa = SampleID, lab = SampleID)
if(length(tiss)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Tissue), lab)
if(length(genos)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Genotype), lab)
if(length(treas)>1) tp = tp %>% mutate(lab = sprintf("%s %s", lab, Treatment), lab)
tp = tp %>% select(taxa, everything())
fo = sprintf("%s/21.cpm.hclust.pdf", dirw)
plot_hclust_tree(tree, tp, fo, 
                 labsize = config::get("hc.labsize"), 
                 x.expand = config::get("hc.x.expand"),
                 x.off = config::get("hc.x.off"), 
                 wd = config::get("hc.wd"), ht = config::get("hc.ht"))

is_tip <- tree$edge[,2] <= length(tree$tip.label)
ordered_tips = tree$edge[is_tip,2]
lnames = tree$tip.label[ordered_tips]
df_mat = data.frame(as.matrix(1-e.c.dist))[,rev(lnames)]

                 labsize = config::get("hc.labsize")
                 x.expand = config::get("hc.x.expand")
                 x.off = config::get("hc.x.off")
                 wd = config::get("hc.wd")
                 ht = config::get("hc.ht")
    cols1 = c('gray80','black','red','seagreen3', pal_d3()(5))
    p1 = ggtree(tree) +
        #geom_tiplab(size = labsize, color = 'black') +
        scale_x_continuous(expand = expand_scale(mult=c(.02,x.expand))) +
        scale_y_discrete(expand = c(.01,0)) +
        theme_tree2()
    p1 = p1 %<+% tp +
        geom_tiplab(aes(label = lab), size = labsize, offset = x.off, family = 'mono')
        #geom_text(aes(label = SampleID), size = 2, nudge_x = .001, hjust = 0) +
        #geom_text(aes(label = Genotype), size = 2, nudge_x= .015, hjust = 0) +
        #geom_text(aes(label = Rep), size = 2, nudge_x = .022, hjust = 0)
p2 = gheatmap(p1, df_mat, offset = 10, width = 10, colnames = F)
ggsave(p2, filename = fo, width = 12, height = 10)
#}}}

#{{{ pheatmap
pdf(sprintf("%s/xx.pdf", dirw), width = 10, height = 5)
plot(ehc)
dev.off()

require(dendsort)
#mat <- as.dist(cor(e, method = 'pearson'))
#hc <- hclust(mat, method = 'ward.D')
edist <- as.dist(1-cor(e, method = cor_opt))
ehc <- hclust(edist, method = hc_opt)
lnames = ehc$labels
mat = 1 - as.matrix(edist)
#mat = mat[lnames,rev(lnames)]
th = th %>% mutate(SampleID = factor(SampleID, levels = lnames)) %>%
    arrange(SampleID)
fo = sprintf("%s/21.heatmap.pdf", dirw)
pheatmap(
    mat               = mat,
    #color             = inferno(length(mat_breaks) - 1),
    #breaks            = mat_breaks,
    border_color      = NA,
    cluster_cols      = ehc,
    cluster_rows      = ehc,
    show_colnames     = F,
    show_rownames     = T,
    labels_row        = th$Tissue,
    #annotation_row    = th[,c('SampleID','sid')],
    #annotation_colors = pal_d3()(10),
    drop_levels       = T,
    fontsize          = 7,
    main              = "Dev. Atlas 122 Tissues",
    filename          = fo,
    width             = 11,
    height            = 10
)

  cellwidth = 30, cellheight = 30, scale = "none",
  treeheight_row = 200,
  kmeans_k = NA,
  show_rownames = T, show_colnames = F,
  clustering_method = "complete",
  cluster_rows = T, cluster_cols = T,
  #clustering_distance_rows = drows1, 
  #clustering_distance_cols = dcols1,
  #annotation_col = ta,
  #annotation_colors = ann_colors,

#}}}

#{{{ PCA
pca <- prcomp(asinh(e), center = F, scale. = F)
x = pca['rotation'][[1]]
y = summary(pca)$importance
y[,1:5]
xlab = sprintf("PC1 (%.01f%%)", y[2,1]*100)
ylab = sprintf("PC2 (%.01f%%)", y[2,2]*100)
#
tp = as_tibble(x[,1:5]) %>%
    add_column(SampleID = rownames(x)) %>%
    left_join(th, by = 'SampleID') %>%
    mutate(Treatment = factor(Treatment))
fo = sprintf("%s/22.pca.pdf", dirw)
plot_pca(tp, fo, opt = config::get("pca.opt"), labsize = config::get("pca.labsize"),
         wd = config::get("pca.wd"), ht = config::get("pca.ht"))
#}}}


