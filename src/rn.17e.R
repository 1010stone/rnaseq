source("functions.R")

yid = 'rn17e'
dirw = file.path(dird, '11_qc', yid)
if(!dir.exists(dirw)) dir.create(dirw)

#{{{ read in, filter/fix samples
res = rnaseq_cpm_raw(yid)
th = res$th; tm = res$tm; tl = res$tl; th_m = res$th_m; tm_m = res$tm_m

th = res$th %>%
    mutate(lab = str_c(Tissue, Genotype, Treatment, Replicate, sep='_'))
tm = res$tm %>% filter(SampleID %in% th$SampleID) %>%
    mutate(value=asinh(CPM))
#}}}

#{{{ hclust & tSNE
p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='pearson',var.col='Genotype',
    expand.x=.3)
ggsave(file.path(dirw, '11.hclust.p.pdf'), p1, width=6, height=8)

p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='spearman',var.col='Genotype',
    expand.x=.3)
ggsave(file.path(dirw, '11.hclust.s.pdf'), p1, width=6, height=8)

p2 = plot_pca(tm,th,pct.exp=.7, pca.center=T, pca.scale=F,
    var.shape='Treatment', var.col='Tissue', var.lab='Genotype',
    legend.pos='left.top', legend.dir='v', pal.col='aaas')
ggsave(file.path(dirw, '11.pca.pdf'), p2, width=6, height=6)

p3 = plot_tsne(tm,th,pct.exp=.7,perp=3,iter=1200, seed=42,
    var.shape='Treatment', var.col='Tissue', var.lab='Genotype',
    legend.pos='top.right', legend.dir='v', pal.col='aaas')
ggsave(file.path(dirw, '11.tsne.pdf'), p3, width=6, height=6)
#}}}

#{{{ raw: filter/fix samples
th2 = res$th

fh = file.path(dirw, '01.meta.tsv')
write_tsv(th2, fh, na='')
#}}}

#{{{ hclust & tSNE
p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='pearson',var.col='Genotype',
    expand.x=.3)
ggsave(file.path(dirw, '21.hclust.p.pdf'), p1, width=6, height=8)

p1 = plot_hclust(tm,th,pct.exp=.7,cor.opt='spearman',var.col='Genotype',
    expand.x=.3)
ggsave(file.path(dirw, '21.hclust.s.pdf'), p1, width=6, height=8)

p2 = plot_pca(tm,th,pct.exp=.7, pca.center=T, pca.scale=F,
    var.shape='Treatment', var.col='Tissue', var.lab='Genotype',
    legend.pos='top.left', legend.dir='v', pal.col='aaas')
ggsave(file.path(dirw, '21.pca.pdf'), p2, width=6, height=6)

p3 = plot_tsne(tm,th,pct.exp=.7,perp=3,iter=1200, seed=42,
    var.shape='Treatment', var.col='Tissue', var.lab='Genotype',
    legend.pos='top.right', legend.dir='v', pal.col='aaas')
ggsave(file.path(dirw, '21.tsne.pdf'), p3, width=6, height=6)
#}}}


