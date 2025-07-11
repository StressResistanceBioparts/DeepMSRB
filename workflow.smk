# Snakefile

# 配置文件路径
configfile: "config/config.yaml"

import os

# # 样本路径和输出目录
samples_path = config["samples_path"]
SAMPLES = [".".join(i.split(".")[0:-1]) for i in os.listdir(samples_path)]
# # SAMPLES = [i.replace(".fasta", "") for i in os.listdir(samples_path)]
DL_Predict_result = "DWFB_results/0/1.DL_Predict_result"
DeepGoPlus_result = "DWFB_results/0/2.DeepGoPlus_result"
GO_anno_result = "DWFB_results/0/3.GO_anno_result"
final_element_select = "DWFB_results/0/4.final_element_select"
seqkit_grep_seq = "DWFB_results/0/5.final_seq_get"


rule all:
    input:
        # 确保包含 ph、tp、ox 文件夹中的所有 .fasta 文件
        expand(seqkit_grep_seq + "/ph/{sample}_ph.fasta", sample=SAMPLES),
        expand(seqkit_grep_seq + "/tp/{sample}_tp.fasta", sample=SAMPLES),
        expand(seqkit_grep_seq + "/ox/{sample}_ox.fasta", sample=SAMPLES)


# 定义深度学习预测抗逆元件规则
rule DL_Predict:
    input: 
        samples_path + "/{sample}.fa"
    output: 
        DL_Predict_result + "/{sample}_predicted.fasta"
    conda:
        "tensorflow"
    shell:
         "DL_Predict_UPDATE -i {input} -o {output}"

# 定义GO注释规则
rule deepgoplus:
    input: 
        rules.DL_Predict.output
    output: 
        DeepGoPlus_result + "/{sample}_deepgoplus_output.tsv"
    conda:
        "DGP"
    shell:
         "deepgoplus -dr /home/map/software/data -if {input} -of {output}"

# 定义GO注释结果统计分析规则
rule GO_anno_from_tab:
    input:  
        rules.deepgoplus.output  # 需要替换为实际的GO annotation文件路径
    output: 
        DeepGoPlus_result + "/{sample}_deepgoplus_output_GO_anno.xls"
    conda:
        "base"
    shell: 
        "GO_anno_from_tab -i {input}"

# 定义筛选pH胁迫相关基因规则
rule element_select_ph:
    input: 
        rules.GO_anno_from_tab.output
    output:
        final_element_select + "/{sample}_filtered_genes_ph.txt"
    shell:
        "element_select -i {input} -o {output} -f ph"

# 定义筛选温度胁迫相关基因规则
rule element_select_tp:
    input: 
        rules.GO_anno_from_tab.output
    output:
        final_element_select + "/{sample}_filtered_genes_tp.txt"
    shell:
        "element_select -i {input} -o {output} -f tp"

# 定义筛选氧化应激相关基因规则
rule element_select_ox:
    input: 
        rules.GO_anno_from_tab.output
    output:
        final_element_select + "/{sample}_filtered_genes_ox.txt"
    shell:
        "element_select -i {input} -o {output} -f ox"

# 根据序列ID，提取序列
rule seq_grep_ph:
    input:
        r1 = rules.element_select_ph.output,
        r2 = rules.DL_Predict.input
    output:
        seqkit_grep_seq + "/ph/{sample}_ph.fasta"
    shell:
        "seqkit grep -f {input.r1} {input.r2} -o {output} && "
        "if [ ! -s {output} ]; then echo 'Sorry, the tolerance element was not predicted in the sequence you provided. 抱歉，未能在您提供的序列中预测得到抗逆元件。' >&2; fi"


# 根据序列ID，提取序列
rule seq_grep_tp:
    input:
        r1 = rules.element_select_tp.output,
        r2 = rules.DL_Predict.input
    output:
        seqkit_grep_seq + "/tp/{sample}_tp.fasta"
    shell:
        "seqkit grep -f {input.r1} {input.r2} -o {output} && "
        "if [ ! -s {output} ]; then echo 'Sorry, the tolerance element was not predicted in the sequence you provided. 抱歉，未能在您提供的序列中预测得到抗逆元件。' >&2; fi"


# 根据序列ID，提取序列
rule seq_grep_ox:
    input:
        r1 = rules.element_select_ox.output,
        r2 = rules.DL_Predict.input
    output:
        seqkit_grep_seq + "/ox/{sample}_ox.fasta"
    shell:
        "seqkit grep -f {input.r1} {input.r2} -o {output} && "
        "if [ ! -s {output} ]; then echo 'Sorry, the tolerance element was not predicted in the sequence you provided. 抱歉，未能在您提供的序列中预测得到抗逆元件。' >&2; fi"



# # 定义规则之间的依赖关系
# DL_Predict.output >> deepgoplus.input
# deepgoplus.output >> GO_anno_from_tab.input
# element_select.output >> all.output
