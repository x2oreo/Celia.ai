// OWNER: Georgi — tab body. Agent chat (home) goes here; calls AgentCore.get().send(text).

import { PlaceholderView } from '../components/PlaceholderView';

@ComponentV2
export struct AgentPage {
  build() {
    PlaceholderView({
      icon: $r('app.media.ic_tab_agent'),
      title: $r('app.string.agent_title'),
      subtitle: $r('app.string.agent_placeholder')
    })
  }
}
