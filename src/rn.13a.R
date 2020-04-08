source("functions.R")

yid = 'rn13a'
dirw = file.path(dird, '11_qc', yid)
if(!dir.exists(dirw)) system(sprintf("mkdir -p %s", dirw))

#{{{ read in, filter/fix samples
ref = t_cfg %>% filter(yid == !!yid) %>% pull(ref)
th = rnaseq_sample_meta(yid)
tt = rnaseq_mapping_stat(yid)
res = rnaseq_cpm_raw(yid)
th = res$th; tm = res$tm; tl = res$tl; th_m = res$th_m; tm_m = res$tm_m
sum_stat_tibble(tt)

sids_keep = tt %>% filter(mapped>5) %>% pull(SampleID)
sum_stat_tibble(tt %>% filter(SampleID %in% sids_keep))

# fix th
th2 = th %>% filter(SampleID %in% sids_keep)
th2 = complete_sample_list(th2)


th = th2
tt = tt %>% filter(SampleID %in% th$SampleID)

fh = file.path(dirw, 'meta.tsv')
write_tsv(th, fh, na='')
# run snakemake again
#}}}

res = rnaseq_cpm(yid)
th = res$th; tm = res$tm; tl = res$tl; th_m = res$th_m; tm_m = res$tm_m
th = th %>% mutate(lab = sprintf("%s_%s", Genotype, Replicate))

#{{{ hclust
tw = tm %>% select(SampleID, gid, CPM) %>% mutate(CPM=asinh(CPM)) %>% spread(SampleID, CPM)
t_exp = tm %>% group_by(gid) %>% summarise(n.exp = sum(CPM>=1))
gids = t_exp %>% filter(n.exp >= (ncol(tw)-1) * .7) %>% pull(gid)
e = tw %>% filter(gid %in% gids) %>% select(-gid)
dim(e)

cor_opt = "spearman"
cor_opt = "pearson"
hc_opt = "ward.D"
hc_title = sprintf("dist: %s\nhclust: %s", cor_opt, hc_opt)
edist <- as.dist(1-cor(e, method = cor_opt))
ehc <- hclust(edist, method = hc_opt)
tree = as.phylo(ehc)
lnames = ehc$labels[ehc$order]
#
tp = th %>% mutate(taxa = SampleID) %>%
    select(taxa, everything())
p1 = ggtree(tree, layout = 'rectangular') +
    scale_x_continuous(expand = expand_scale(0,.1)) +
    scale_y_discrete(expand = c(.01,0))
p1 = p1 %<+%
    tp + geom_tiplab(aes(label=lab, color=Genotype), size=2.5) +
    scale_color_viridis_d()
fo = sprintf("%s/21.cpm.hclust.pdf", dirw)
ggsave(p1, filename = fo, width=8, height=12)
#}}}

#{{{ tSNE
require(Rtsne)
tw = tm %>% select(SampleID, gid, CPM) %>% mutate(CPM=asinh(CPM)) %>% spread(SampleID, CPM)
t_exp = tm %>% group_by(gid) %>% summarise(n.exp = sum(CPM>=1))
gids = t_exp %>% filter(n.exp >= (ncol(tw)-1) * .7) %>% pull(gid)
tt = tw %>% filter(gid %in% gids)
dim(tt)
tsne <- Rtsne(t(as.matrix(tt[-1])), dims=2, verbose=T, perplexity=10,
              pca = T, max_iter = 1500)

tp = as_tibble(tsne$Y) %>%
    add_column(SampleID = colnames(tt)[-1]) %>%
    inner_join(th, by = 'SampleID')
x.max=max(tp$V1)
p_tsne = ggplot(tp) +
    geom_text_repel(aes(x=V1,y=V2,label=Genotype), size=2.5) +
    geom_point(aes(x=V1, y=V2, color=Genotype, shape=as.character(Replicate)), size=2) +
    scale_x_continuous(name = 'tSNE-1') +
    scale_y_continuous(name = 'tSNE-2') +
    scale_shape_manual(values = c(15,0)) +
    scale_color_viridis_d(name = 'Genotype',direction=-1) +
    #scale_color_ucscgb(name = 'hours after cold') +
    otheme(legend.pos='top.left', legend.dir='v', legend.title=T,
           xtitle=T, ytitle=T,
           margin = c(.2,.2,.2,.2)) +
    theme(axis.ticks.length = unit(0, 'lines')) +
    guides(color = F)
fp = file.path(dirw, "25.tsne.pdf")
ggsave(p_tsne, filename = fp, width=8, height=8)
#}}}


#{{{ convert RIL genotype to phylip
fi = file.path(dird, 'raw', yid, 'ril.rds')
res = readRDS(fi)
write_phylip <- function(tp, fo) {
    #{{{
    nind = nrow(tp); nsite = nchar(tp$gt[1])
    write_tsv(tibble(x=nind, y=nsite), fo, append=T, col_names=F)
    write_tsv(tp, fo, append=T, col_names=F)
    #}}}
}

tp = res$bin %>% filter(rid != 'r11') %>%
    mutate(gt2=ifelse(gt=='a','0',ifelse(gt=='b','2','1'))) %>%
    arrange(SampleID, rid, start, end) %>%
    group_by(SampleID) %>%
    summarise(gt = str_c(gt2, collapse='')) %>%
    ungroup()

fo = file.path(dirw, '41.phy')
write_phylip(tp, fo)
#}}}

#{{{ plot tree
require(ape)
require(treeio)
require(ggtree)
require(tidytree)
fi = file.path(dirw, '41.phy.treefile')
tree = read.newick(fi)
tp = fortify(tree) %>% filter(isTip) %>%
    arrange(y) %>%
    left_join(th, by=c('label'='SampleID')) %>%
    #filter(!is.na(label)) %>%
    mutate(gt = ifelse(Genotype %in% gts, 'ref', ifelse(Genotype %in% gts1, 'select1', ifelse(Genotype %in% gts2,'select2','all'))))

g1 = tp %>% filter(row_number() %% 2 != 0) %>% pull(Genotype)
g2 = tp %>% filter(row_number() %% 2 == 0) %>% pull(Genotype)
identical(g1, g2)
sids = tp %>% filter(row_number() %% 2 != 0) %>% pull(label)

cols10 = c('black', pal_aaas()(10)[2:10])
p1 = ggtree(tree) %<+% tp +
    geom_tiplab(aes(label=lab,col=gt), size=2, hjust=0, align=T, linesize=.5) +
    scale_color_manual(values = cols10) +
    scale_x_continuous(expand=expand_scale(mult=c(.02,.1))) +
    scale_y_continuous(expand=expand_scale(mult=c(.01,.01))) +
    guides(color=F)
fo = file.path(dirw, '43.phylogeny.pdf')
ggsave(p1, file=fo, width=6, height=15)
#}}}

gts = c("B73","Mo17")
gts1 = c("M0021","M0317","M0014","M0016")
gts2 = c('M0275','M0352','M0326','M0323','M0035','M0012','M0017','M0001')
sids_red = th %>% filter(Genotype %in% c(gts, gts1, gts2)) %>% pull(SampleID)
#{{{ RIL haplotype blocks
cp = res$ril$cp
p = plot_ril_genotype(cp, th, sids_red=sids_red)
fo = file.path(dirw, '41.ril.genotype.pdf')
ggsave(fo, p, width=8, height=15)
#}}}

