package org.broadinstitute.dsde.firecloud.test.analysis

import org.broadinstitute.dsde.firecloud.fixture.UserFixtures
import org.broadinstitute.dsde.firecloud.page.workspaces.WorkspaceDataPage
import org.broadinstitute.dsde.firecloud.page.workspaces.methodconfigs.WorkspaceMethodConfigDetailsPage
import org.broadinstitute.dsde.workbench.auth.AuthToken
import org.broadinstitute.dsde.workbench.config.UserPool
import org.broadinstitute.dsde.workbench.fixture._
import org.broadinstitute.dsde.workbench.service.test.WebBrowserSpec
import org.scalatest.{FreeSpec, Matchers}

class MethodConfigSpec extends FreeSpec with Matchers with WebBrowserSpec with WorkspaceFixtures with UserFixtures with MethodFixtures with BillingFixtures {

  "input/output auto-suggest" - {
    "stays current with selected root entity type" in {
      val user = UserPool.chooseProjectOwner
      implicit val authToken: AuthToken = user.makeAuthToken()
      withCleanBillingProject(user) { projectName =>
        withWorkspace(projectName, "MethodConfigSpec", attributes = Some(Map("foo" -> "bar"))) { workspaceName =>
          val configName = s"${SimpleMethodConfig.configName}_$workspaceName"
          api.methodConfigurations.createMethodConfigInWorkspace(
            projectName, workspaceName,
            MethodData.SimpleMethod,
            projectName, configName,
            SimpleMethodConfig.snapshotId,
            Map.empty, Map.empty,
            "sample")

          val workspaceSuggestions = Seq("workspace.foo")
          val participantSuggestions = Seq("this.is_a_participant")

          withWebDriver { implicit driver =>
            withSignIn(user) { _ =>
              val configPage = new WorkspaceMethodConfigDetailsPage(projectName, workspaceName, projectName, configName).open
              configPage.isEditing shouldBe false

              configPage.toggleDataModel() shouldBe false
              configPage.isEditing shouldBe true
              configPage.clickAndReadSuggestions("test.hello.name") should contain theSameElementsAs workspaceSuggestions

              configPage.toggleDataModel() shouldBe true
              configPage.readRootEntityTypeSelect shouldBe "sample"
              configPage.clickAndReadSuggestions("test.hello.name") should contain theSameElementsAs workspaceSuggestions

              api.importMetaData(projectName, workspaceName, "entities",
                "entity:participant_id\tis_a_participant\nparticipant1\ttrue")

              // go somewhere else and come back (because reloadPage loses background signed-in state)
              new WorkspaceDataPage(projectName, workspaceName).open
              configPage.open

              configPage.openEditMode()
              configPage.readRootEntityTypeSelect shouldBe "sample"
              configPage.clickAndReadSuggestions("test.hello.name") should contain theSameElementsAs workspaceSuggestions

              configPage.selectRootEntityType("participant")
              configPage.clickAndReadSuggestions("test.hello.name") should contain theSameElementsAs workspaceSuggestions ++ participantSuggestions

              // Unchecking data model should suppress participant suggestions
              configPage.toggleDataModel() shouldBe false
              configPage.clickAndReadSuggestions("test.hello.name") should contain theSameElementsAs workspaceSuggestions

              configPage.toggleDataModel() shouldBe true
              configPage.readRootEntityTypeSelect shouldBe "participant"
              configPage.clickAndReadSuggestions("test.hello.name") should contain theSameElementsAs workspaceSuggestions ++ participantSuggestions
            }
          }
        }
      }
    }
  }
}
