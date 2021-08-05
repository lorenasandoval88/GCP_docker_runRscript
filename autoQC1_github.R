# Rcode to deploy docker image to GCP and run R script sitting in a bucket on a schedule

##install.packages("googleCloudRunner")
#install.packages("googleAuthR")
library("googleCloudRunner")
library("googleAuthR")

# GCP permissions for service account
#cloudscheduler.jobs.create , Cloud Build Editor, iam.serviceAccounts.actAs

# set .Renviron file
readRenviron("C:/Users/---/Documents/.Renviron")

# setup authentication via cr_setup()
#(NOT WORKING)----------------------------------------------------
#cr_setup() 

# or #(NOT WORKING)
cr_region_set("region")
cr_bucket_set("bucket")
cr_email_set("email")
cr_project_set("project")

# or You can also set the above in the R scripts via gar_auth_service(), service  credentials: 
#(WORKING) -------------------------------------------------------------

googleAuthR::gar_auth_service("C:/Users/sandovall2/Downloads/service account json")

# Perform deployments to test your setup is working
#cr_setup_test()

######################## create an R docker image from existing session
# uses packages from current session
# https://o2r.info/containerit/
# install.packages("remotes")
#remotes::install_github("o2r-project/containerit")
# suppressPackageStartupMessages(library("containerit"))
# 
# # install packages in current environent into new docker file and view
# my_dockerfile <- containerit::dockerfile(from = utils::sessionInfo())
# 
# # view dockerfile created
# cat(as.character(format(my_dockerfile)), sep = "\n")
# 
# # save dockerfile
# write(my_dockerfile, file = "Dockerfile")


########################## If you need to build your own with a Dockerfile include that in a step before your R code runs
my_r_script <- "gs://qc_automation/here.R"
my_dockerfile_folder <- "gs://qc_automation"

# deploy dockerfile
# switch bucket configuration to fine grained rather than uniform access control
cr_deploy_docker("C:/Users/---/Documents/myDocker",
                 image_name = "gcr.io/project/mydocker")

# build your image called my-r-docker
# cr_deploy_docker(local=my_dockerfile_folder, 
#                  image_name = "gcr.io/project/mydocker",
#                  bucket = "",
#                  projectId = "",
#                  remote = "gs://qc_automation")


# now the buildstep uses the built image
bs <- cr_buildstep_r(
  my_r_script,
  name = "gcr.io/nih-nci-dceg-connect-dev/mydocker:latest")

########################## Run an R script in a Cloud Build R step
#https://code.markedmondson.me/googleCloudRunner/reference/cr_buildstep_r.html
# here you can add metadata for the build steps, such as timeout
my_build <- cr_build_yaml(bs, timeout = 2400)

# build it
b <- cr_build(my_build)
built <- cr_build_wait(b)

#To set this up in a schedule, add it to the scheduler like so:
schedule_me <- cr_build_schedule_http(built)

# error arises in cr_schedule
#https://stackoverflow.com/questions/59557008/cannot-deploy-as-a-service-account-to-google-cloud-run
# security fix with 2 service accounts
#https://stackoverflow.com/questions/64236468/cloud-build-fails-to-deploy-to-google-app-engine-you-do-not-have-permission-to
cr_schedule("rBQ", schedule = "0 9 * * 1-5",  # run Monday-Friday 9AM
            httpTarget = cr_build_schedule_http(b,email = "service account email"))
