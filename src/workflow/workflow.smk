# Snakefile

# 配置文件路径
configfile: "config/config.yaml"

import os

# 样本路径和输出目录

RESULT_ROOT = "../../result"  # 根目录

samples_path = config["samples_path"]
SAMPLES = [".".join(i.split(".")[0:-1]) for i in os.listdir(samples_path)]
DL_Predict_result = os.path.join(RESULT_ROOT, "1.DL_Predict_result")        # 新增路径嵌套
DeepGoPlus_result = os.path.join(RESULT_ROOT, "2.DeepGoPlus_result")
GO_anno_result = os.path.join(RESULT_ROOT, "3.GO_anno_result")
final_element_select = os.path.join(RESULT_ROOT, "4.final_element_select")
seqkit_grep_seq = os.path.join(RESULT_ROOT, "5.final_seq_get")

# 运行状态邮件推送

onsuccess:
    print(f"所有结果已保存至{RESULT_ROOT}目录！")
    shell('notifyMe -c "snakemake -s workflow.smk -c 20 --use-conda -p --stats stats.json" -e "xt33kaka@163.com" -s 0 -t "任务已完成，祝你接下来实验顺利"')

onerror:
    shell('notifyMe -c "snakemake -s workflow.smk -c 20 --use-conda -p --stats stats.json" -e "xt33kaka@163.com" -s 1 -t "重启任务"')

# rule all:
#     input: 
#         # expand(os.path.join(final_element_select, "{sample}_filtered_genes.txt"), sample=SAMPLES)
#         expand(os.path.join(seqkit_grep_seq, "{sample}_ph.fasta"), sample=SAMPLES) 

localrules: all
rule create_dirs:
    run:
        os.makedirs(DL_Predict_result, exist_ok=True)
        os.makedirs(DeepGoPlus_result, exist_ok=True)
        os.makedirs(final_element_select, exist_ok=True)
        os.makedirs(seqkit_grep_seq + "/ph", exist_ok=True)
        os.makedirs(seqkit_grep_seq + "/tp", exist_ok=True)
        os.makedirs(seqkit_grep_seq + "/ox", exist_ok=True)

rule all:
    input:
        expand(os.path.join(seqkit_grep_seq, "ph/{sample}_ph.fasta"), sample=SAMPLES),
        expand(os.path.join(seqkit_grep_seq, "tp/{sample}_tp.fasta"), sample=SAMPLES),
        expand(os.path.join(seqkit_grep_seq, "ox/{sample}_ox.fasta"), sample=SAMPLES),
    _FIRST: create_dirs  # 隐式依赖目录创建



# 定义深度学习预测抗性基因规则
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

# rule element_select:
#     input: 
#         rules.GO_anno_from_tab.output
#     output:
#         final_element_select + "/{sample}_filtered_genes.txt"
#     shell: 
#         "element_select -i {input} -o {output} -f ph"

# rule seq_grep:
#     input:
#        r1 =  rules.element_select.output,
#        r2 = rules.DL_Predict.input
#     output:
#         seqkit_grep_seq + "/{sample}_ph.fasta"
#     shell:
#         "seqkit grep -f {input.r1} {input.r2} -o {output} &&"
#         "if [ ! -s {output} ]; then echo 'Sorry, the tolerance element was not predicted in the sequence you provided.抱歉，未能在您提供的序列中预测得到抗逆元件。' >&2; fi"
 


# # 定义规则之间的依赖关系
# DL_Predict.output >> deepgoplus.input
# deepgoplus.output >> GO_anno_from_tab.input
# element_select.output >> all.output
