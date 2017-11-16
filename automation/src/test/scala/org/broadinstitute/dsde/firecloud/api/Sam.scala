package org.broadinstitute.dsde.firecloud.api

import akka.http.scaladsl.model.StatusCodes
import com.typesafe.scalalogging.LazyLogging
import org.broadinstitute.dsde.firecloud.config.{AuthToken, Config}
import org.broadinstitute.dsde.firecloud.api.Sam.user.UserStatusDetails
import org.broadinstitute.dsde.firecloud.config.UserPool
import org.broadinstitute.dsde.firecloud.dao.Google.googleIamDAO
import org.broadinstitute.dsde.workbench.google.model.GoogleProject
import org.broadinstitute.dsde.workbench.model.WorkbenchUserServiceAccountName
import org.scalatest.time.{Seconds, Span}
import org.scalatest.concurrent.ScalaFutures
import org.broadinstitute.dsde.firecloud.auth.AuthToken
import org.broadinstitute.dsde.firecloud.config.Config
import org.broadinstitute.dsde.workbench.model.WorkbenchUserServiceAccountEmail

/**
  * Sam API service client. This should only be used when Orchestration does
  * not provide a required endpoint. This should primarily be used for admin
  * functions.
  */
object Sam extends FireCloudClient with LazyLogging with ScalaFutures{

  private val url = Config.FireCloud.samApiUrl

  implicit override val patienceConfig: PatienceConfig = PatienceConfig(timeout = scaled(Span(5, Seconds)))

  def petName(userInfo: UserStatusDetails) = WorkbenchUserServiceAccountName(s"pet-${userInfo.userSubjectId}")

  def removePet(userInfo: UserStatusDetails): Unit = {
    Sam.admin.deletePetServiceAccount(userInfo.userSubjectId)(UserPool.chooseAdmin.makeAuthToken())
    // TODO: why is this necessary?  GAWB-2867
    googleIamDAO.removeServiceAccount(GoogleProject(Config.Projects.default), petName(userInfo)).futureValue
  }

  object admin {

    def deleteUser(subjectId: String)(implicit token: AuthToken): Unit = {
      logger.info(s"Deleting user: $subjectId")
      deleteRequest(url + s"api/admin/user/$subjectId")
    }

    def doesUserExist(subjectId: String)(implicit token: AuthToken): Option[Boolean] = {
      getRequest(url + s"api/admin/user/$subjectId").status match {
        case StatusCodes.OK => Option(true)
        case StatusCodes.NotFound => Option(false)
        case _ => None
      }
    }
  }
}
