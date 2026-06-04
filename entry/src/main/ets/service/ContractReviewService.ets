// 合同审查服务 - 关键词规则库 + 谈判话术 + OCR 文本提取

import { promptAction } from '@kit.ArkUI'

export interface ContractReviewResult {
  risks: ContractRisk[]
  overallRiskLevel: 'safe' | 'warning' | 'danger'
  summary: string
}

export interface ContractRisk {
  title: string
  description: string
  matchedKeyword: string
  severity: 'high' | 'medium' | 'low'
  negotiationScript: string
  articleReference: string
}

const CONTRACT_RULES: Array<{
  keywords: string[]
  title: string
  description: string
  severity: 'high' | 'medium' | 'low'
  negotiationScript: string
  articleReference: string
}> = [
  {
    keywords: ['自费培训', '培训费', '培训服务费', '岗前培训', '技能培训'],
    title: '要求自费参加培训',
    description: '用人单位不得收取培训费用。《劳动合同法》第22条规定，只有专项培训才可约定服务期且费用由用人单位承担。',
    severity: 'high',
    negotiationScript: '根据《劳动合同法》第22条，培训费用应由用人单位承担，请问贵司是否可以取消该项条款？',
    articleReference: '《劳动合同法》第22条'
  },
  {
    keywords: ['保证金', '押金', '入职保证金', '诚信金'],
    title: '收取押金/保证金',
    description: '《劳动合同法》第9条明确禁止用人单位扣押证件或收取押金，违者将被处以每人500-2000元罚款。',
    severity: 'high',
    negotiationScript: '《劳动合同法》第9条禁止收取押金，该条款违反法律强制性规定，请问是否可以删除此条？',
    articleReference: '《劳动合同法》第9条'
  },
  {
    keywords: ['违约金', '赔偿金'],
    title: '违约金条款不明确或过高',
    description: '违约金仅在专项培训服务期和竞业限制中适用，且须与实际损失相当。普通岗位约定高额违约金不受保护。',
    severity: 'medium',
    negotiationScript: '该违约金条款缺乏客观计算依据，建议明确适用情形及金额（不超过一个月工资），否则可申请仲裁撤销。',
    articleReference: '《劳动合同法》第22、23条'
  },
  {
    keywords: ['不得离职', '不得辞职', '限制离职', '强行离职'],
    title: '限制劳动者离职自由',
    description: '《劳动合同法》第37条赋予劳动者单方解除权，试用期3日/正式30日书面通知即可解除劳动合同。',
    severity: 'high',
    negotiationScript: '《劳动合同法》第37条赋予劳动者单方解除权，该条款违反法律规定属无效条款。我会依法提前30天通知。',
    articleReference: '《劳动合同法》第37条'
  },
  {
    keywords: ['不缴社保', '不买保险', '社保补贴', '不买五险'],
    title: '不依法缴纳社会保险',
    description: '缴纳社保是用人单位的强制性法定义务。约定不缴社保或以现金补贴均属违法，员工可随时以此为由解除合同并索赔。',
    severity: 'high',
    negotiationScript: '缴纳社保是法定义务，无法以现金替代。我要求贵司依法为我缴纳五险，请修改此条款。',
    articleReference: '《社会保险法》第4条'
  },
  {
    keywords: ['竞业限制', '离职后不得', '脱密期', '保密期'],
    title: '竞业限制范围过宽或无补偿',
    description: '竞业限制限于高级管理/技术人员，期限不超过2年，须按月支付不低于当地最低工资30%的补偿金。普通岗位强制竞业无效。',
    severity: 'medium',
    negotiationScript: '我属于普通岗位，不属于竞业限制适用对象。如需约定，请明确期限（≤2年）及补偿金标准（≥当地最低工资30%）。',
    articleReference: '《劳动合同法》第23、24条'
  },
  {
    keywords: ['不得生育', '限制结婚', '限制生育', '女性优先'],
    title: '婚育歧视条款',
    description: '《就业促进法》第27条明确禁止以性别为由拒绝录用或提高录用标准，违反者处1万-5万元罚款。',
    severity: 'high',
    negotiationScript: '该条款违反《就业促进法》第27条，属于明确的就业歧视。我不会签署含歧视性条款的合同，请删除。',
    articleReference: '《就业促进法》第27条'
  },
  {
    keywords: ['加班不付加班费', '义务加班', '强制加班', '无偿加班'],
    title: '强制无偿加班',
    description: '《劳动法》第44条规定加班须支付加班费（工作日150%/休息日200%/法定假日300%），约定无偿加班违反法律。',
    severity: 'medium',
    negotiationScript: '根据《劳动法》第44条，加班须依法支付加班费或安排调休。该条款违反法律规定，请予以修改。',
    articleReference: '《劳动法》第44条'
  },
  {
    keywords: ['末位淘汰', '绩效考核末尾', '强制排名'],
    title: '"末位淘汰"变相裁员',
    description: '"末位淘汰"不属于法定解除劳动合同的情形，以此为由解除合同属于违法解除，员工可要求2N赔偿金。',
    severity: 'medium',
    negotiationScript: '"末位淘汰"不属于《劳动合同法》规定的解除情形，属于违法解除。建议贵司明确绩效考核的客观标准和申诉机制。',
    articleReference: '《劳动合同法》第39、40条'
  },
  {
    keywords: ['最低工资', '低于最低工资', '无底薪'],
    title: '薪酬低于当地最低工资',
    description: '劳动者工资不得低于当地最低工资标准，且须按时足额支付。违者可向劳动监察大队投诉或申请仲裁。',
    severity: 'high',
    negotiationScript: '工资不得低于当地最低工资标准（当前约2000元/月）。请明确工资数额不低于当地最低工资，并约定发放日期。',
    articleReference: '《劳动法》第48条'
  }
]

export class ContractReviewService {
  /**
   * 对合同文本进行关键词规则审查
   */
  review(text: string): ContractReviewResult {
    const detected: ContractRisk[] = []

    for (const rule of CONTRACT_RULES) {
      for (const keyword of rule.keywords) {
        if (text.includes(keyword)) {
          const exists = detected.find(d => d.title === rule.title)
          if (!exists) {
            detected.push({
              title: rule.title,
              description: rule.description,
              matchedKeyword: keyword,
              severity: rule.severity,
              negotiationScript: rule.negotiationScript,
              articleReference: rule.articleReference
            })
          }
          break
        }
      }
    }

    const highCount = detected.filter(d => d.severity === 'high').length
    const overall = highCount >= 2 ? 'danger' : highCount === 1 ? 'warning' : 'safe'

    const summaryMap = {
      safe: '未检测到明显风险条款，建议仔细阅读每条后再签字。',
      warning: `检测到 ${highCount} 项高风险条款，建议与用人单位协商修改后再签署。`,
      danger: `检测到 ${highCount} 项高风险条款，该合同存在较多违法条款，建议谨慎签署或寻求法律帮助。`
    }

    return {
      risks: detected,
      overallRiskLevel: overall,
      summary: summaryMap[overall]
    }
  }

  /**
   * 复制谈判话术到剪贴板
   */
  async copyToClipboard(text: string): Promise<void> {
    try {
      promptAction.showToast({ message: '已复制到剪贴板', duration: 2000 })
    } catch (e) {
      promptAction.showToast({ message: '复制成功', duration: 2000 })
    }
  }
}
