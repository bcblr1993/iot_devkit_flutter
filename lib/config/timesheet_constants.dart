class TaskDefinition {
  final String code;
  final String name;
  final String scope;
  final String goal;

  const TaskDefinition({
    required this.code,
    required this.name,
    required this.scope,
    required this.goal,
  });
}

class TaskCategoryDefinition {
  final String name;
  final String description;
  final List<TaskDefinition> tasks;

  const TaskCategoryDefinition({
    required this.name,
    required this.description,
    required this.tasks,
  });
}

class TimesheetConstants {
  static const List<TaskCategoryDefinition> categories = [
    TaskCategoryDefinition(
      name: '运维任务类 (Operations)',
      description: '系统的日常稳定运行保障，持续性、重复性工作。',
      tasks: [
        TaskDefinition(
          code: 'SPXMJ2026010200034',
          name: '物联网云平台_现场侧运维任务',
          goal: '高效响应售后现场常规技术问题，保障用户侧系统稳定运行。',
          scope: '现场常规故障排查与修复（配置调整、版本回滚、简单缺陷修复）；现场用户操作指导、需求对接；现场问题修复验证。',
        ),
        TaskDefinition(
          code: 'SPXMJ2026010200037',
          name: '物联网云平台_系统侧常态化运维任务',
          goal: '保障平台基础组件、存储资源、计算引擎稳定运行。',
          scope: '服务器/OS/中间件日常维护与故障修复；数据仓库/业务数据库日常维护；资源监控与扩容。',
        ),
        TaskDefinition(
          code: 'SPXMJ2026010200035',
          name: '物联网云平台_运维管理与知识经验运营',
          goal: '统筹运维全流程协调管理，沉淀运维知识经验。',
          scope: '运维需求沟通澄清；缺失日志获取；跨部门责任分工协调；知识库运营与维护。',
        ),
        TaskDefinition(
          code: 'SPXMJ2026010200036',
          name: '物联网云平台_技术支持与内部培训',
          goal: '降低内部员工使用门槛，提供操作指导。',
          scope: '接入流程咨询；平台应用场景介绍；版本更新后基础操作培训。',
        ),
      ],
    ),
    TaskCategoryDefinition(
      name: '管理任务类 (Management)',
      description: '研发体系通用管理保障，人才/效能/协作/合规。',
      tasks: [
        TaskDefinition(
          code: 'SPXMJ2025123100010',
          name: '团队人才全生命周期管理',
          goal: '聚焦研发团队人才队伍建设，实现“选育用留”规范化。',
          scope: '招聘配置；培养发展（能力测评、培训计划）；绩效管理；员工关系维护。',
        ),
        TaskDefinition(
          code: 'SPXMJ2025123100011',
          name: '团队氛围建设与协作管理',
          goal: '强化跨团队沟通机制，提升凝聚力，降低内耗。',
          scope: '综合协调会议（周会/月会）；团建/激励/分享会；跨团队沟通机制搭建；冲突协调。',
        ),
        TaskDefinition(
          code: 'SPXMJ2025123100012',
          name: '流程合规管理与效能提升',
          goal: '建立标准化研发通用流程体系，规避风险，提升效能。',
          scope: '通用流程设计与推广；合规宣贯与检查（数据安全/知识产权）；效能指标与优化。',
        ),
        TaskDefinition(
          code: 'SPXMJ2025123100013',
          name:
              '知识体系运营与产权管理', // Note: ID same as Project Planning in screenshot row 1? Keeping unique based on name context.
          goal: '实现技术知识有效沉淀、复用与传承。',
          scope: '知识分享活动；知识产权申请（专利/软著）；产权风险排查；知识库搭建（内容更新/搜索优化）。',
        ),
        // Added manually based on "Row 1" in Management Image 3 which had ID 00013
        TaskDefinition(
          code: 'SPXMJ2025123100013', // Duplicate ID warning
          name: '项目统筹规划与流程管理',
          goal: '非单一项目统筹管控，多项目资源统筹。',
          scope: '多项目组合规划；跨项目资源统筹（人力/设备）；整体进度跟踪复盘。',
        ),
      ],
    ),
    TaskCategoryDefinition(
      name: '创新任务类 (Innovation)',
      description: '不可立项的技术探索与创新孵化前期工作。',
      tasks: [
        TaskDefinition(
          code: 'SPXMJ2025123100015',
          name: '新能源前沿技术预研',
          goal: '跟踪行业前沿技术发展趋势。',
          scope: '跨行业前沿技术适配跟踪（AI/区块链）；电力专属前沿技术可行性验证。',
        ),
        TaskDefinition(
          code: 'SPXMJ2025123100016',
          name: '核心技术升级预研',
          goal: '攻克现有系统核心技术瓶颈。',
          scope: '现有系统突破性升级探索；技术瓶颈攻克方案；创新技术组件开发验证。',
        ),
        TaskDefinition(
          code: 'SPXMJ2025123100017',
          name: '业务场景创新探索',
          goal: '挖掘新技术与电力业务融合点。',
          scope: '现有业务场景创新模式探索；新技术与电力业务适配性分析。',
        ),
      ],
    ),
    TaskCategoryDefinition(
      name: '项目任务类 (Project)',
      description: '常规业务交付与技术保障，立项项目。',
      tasks: [
        // Placeholder as specific project codes aren't in screenshots, but category exists in Img 1
        TaskDefinition(
          code: 'PROJECT_GENERAL',
          name: '常规项目开发/交付',
          goal: '既定业务需求落地。',
          scope: '产品功能迭代；适配现有技术升级；复杂程序缺陷修复。',
        ),
      ],
    ),
  ];
}
