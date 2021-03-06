source("functions.R")

yid = 'rn20b2'
dirw = file.path(dird, '11_qc', yid)
if(!dir.exists(dirw)) system(sprintf("mkdir -p %s", dirw))

#{{{ read in, filter/fix samples
res = rnaseq_cpm_raw(yid)
th = res$th; tm = res$tm; tl = res$tl; th_m = res$th_m; tm_m = res$tm_m

th = res$th %>%
    mutate(lab = str_c(Genotype, Replicate, sep='_')) %>%
    mutate(clab = ifelse(Replicate==1, Genotype, ''))
tm = res$tm %>% filter(SampleID %in% th$SampleID) %>%
    mutate(value=asinh(CPM))
#}}}

#{{{ hclust & tSNE
p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='pearson',var.col='Genotype',
    pal.col='viridis_d', expand.x=.2)
ggsave(file.path(dirw, '11.hclust.p.pdf'), p1, width=6, height=8)

p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='spearman',var.col='Genotype',
    pal.col='viridis_d', expand.x=.2)
ggsave(file.path(dirw, '11.hclust.s.pdf'), p1, width=6, height=8)

p2 = plot_pca(tm,th,pct.exp=.7, pca.center=T, pca.scale=F,
    var.shape='', var.col='', var.lab='clab', var.ellipse='Genotype',
    legend.pos='top.left', legend.dir='v', pal.col='')
ggsave(file.path(dirw, '11.pca.pdf'), p2, width=6, height=6)

p3 = plot_tsne(tm,th,pct.exp=.7,perp=4,iter=1000, seed=42,
    var.shape='', var.col='', var.lab='clab', var.ellipse='Genotype',
    legend.pos='top.right', legend.dir='v', pal.col='aaas')
ggsave(file.path(dirw, '11.tsne.pdf'), width=6, height=6)
#}}}

#{{{ fix
th2 = res$th
th2 = complete_sample_list(th2)

fh = file.path(dirw, '01.meta.tsv')
write_tsv(th2, fh, na='')
#}}}

#{{{ read in again
res = rnaseq_cpm(yid)
th = res$th; tm = res$tm; tl = res$tl; th_m = res$th_m; tm_m = res$tm_m

th = th %>%
    mutate(lab = str_c(Genotype, Replicate, sep='_')) %>%
    mutate(clab = ifelse(Replicate==1, Genotype, ''))
tm = res$tm %>% filter(SampleID %in% th$SampleID) %>%
    mutate(value=asinh(CPM))
#}}}

#{{{ hclust & tSNE
p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='pearson',var.col='Genotype',
    pal.col='viridis_d', expand.x=.2)
ggsave(file.path(dirw, '21.hclust.p.pdf'), p1, width=6, height=8)

p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='spearman',var.col='Genotype',
    pal.col='viridis_d', expand.x=.2)
ggsave(file.path(dirw, '21.hclust.s.pdf'), p1, width=6, height=8)

p2 = plot_pca(tm,th,pct.exp=.7, pca.center=T, pca.scale=F,
    var.shape='', var.col='', var.lab='clab', var.ellipse='Genotype',
    legend.pos='top.left', legend.dir='v', pal.col='')
ggsave(file.path(dirw, '21.pca.pdf'), p2, width=6, height=6)

p3 = plot_tsne(tm,th,pct.exp=.7,perp=5,iter=1000, seed=2,
    var.shape='', var.col='', var.lab='clab', var.ellipse='Genotype',
    legend.pos='top.right', legend.dir='v', pal.col='aaas')
ggsave(file.path(dirw, '21.tsne.pdf'), width=6, height=6)
#}}}

#{{{ RIL haplotype blocks
sids_red = th %>% filter(Genotype %in% c("B73")) %>% pull(SampleID)
cp = res$ril$cp
p = plot_ril_genotype(cp, th, sids_red=sids_red)
fo = file.path(dirw, '41.ril.genotype.pdf')
ggsave(fo, p, width=8, height=8)
#}}}

#{{{ write RIL haplotype block coordinates
fw = '~/projects/genome/data/Zmays_B73/15_intervals/20.win11.tsv'
tw = read_tsv(fw)
offs = c(0, cumsum(tw$size)[-nrow(tw)]) + 0:10 * 10e6
tx = tw %>% mutate(off = offs) %>%
    mutate(gstart=start+off, gend=end+off, gpos=(gstart+gend)/2) %>%
    select(rid,chrom,gstart,gend,gpos,off) %>% filter(chrom!='B99')
#
tps = th %>% select(sid=SampleID,Genotype,Replicate) %>% arrange(Genotype) %>%
    mutate(y = 1:n())
tp = res$ril$cp %>% inner_join(tx, by='rid') %>%
    mutate(gstart=start+off, gend=end+off) %>%
    inner_join(tps, by='sid')
#
to = tp %>%
    mutate(sid=str_c(Genotype, Replicate, sep='_')) %>%
    select(sid, chrom,start,end, gt)

fo = file.path(dirw, '42.ril.genotype.tsv')
write_tsv(to, fo)
#}}}
